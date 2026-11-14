//
//  PointsManager.swift
//  GrocartInc-IOS
//
//  Rewards points, driven by the backend loyalty API
//  (Grocart_Loyalty_Points_API.pdf, v1.0, staging).
//
//  Rules (from the server; the fallback defaults live in
//  LoyaltyPointsRules and are used only until the first fetch):
//    • 100 points = $1.00
//    • Earn 1 point per $1 of item subtotal after discounts, rounded
//      down (tax, delivery, service fee and tip earn nothing)
//    • Redeem any amount from 100 points up to the full balance, on any
//      order — the order only spends what it needs and the rest stays
//      banked (no minimum order, no expiry)
//    • Points land when the payment succeeds (card charge/webhook,
//      or cash collection for pickup orders)
//    • Points cannot be combined with coupons or bundle deals
//    • No expiry; the balance can go negative on reversals
//
//  The old on-device system (500 points = $5 off, per-item rounding,
//  a 500-point welcome bonus, points settled on payment success) was
//  replaced by this server-driven one. Its UserDefaults keys
//  ("grocart.points.<id>", "grocart.points.history.<id>") are left in
//  place unread — no stored user data is deleted — but nothing reads
//  them any more. The cached server summary lives under
//  "grocart.points.summary.<id>", so the balance never flashes to
//  zero when the app is offline.
//
//  This manager is the single source of truth for all points UI;
//  views never call the repository. A future welcome bonus or a new
//  rule plugs into PointsRepository / the rules object — no view
//  changes are needed for a new rule.
//

import Foundation
import Combine

/// One row of points history, as the UI shows it. Mapped from a
/// server transaction by `PointsManager.displayTransactions(from:)` —
/// that mapping is the single extension point for new server types.
struct PointsTransaction: Codable, Identifiable {
    /// Server transaction id.
    let id: Int
    let date: Date
    /// Points gained (+) or spent (-).
    let delta: Int
    /// Server description, e.g. "Earned on order TRK-1A2B3C4D".
    let label: String
    let type: PointsTransactionType
    let orderId: Int?
    let trackingId: String?
    let balanceAfter: Int?

    init(id: Int, date: Date, delta: Int, label: String, type: PointsTransactionType, orderId: Int? = nil, trackingId: String? = nil, balanceAfter: Int? = nil) {
        self.id = id
        self.date = date
        self.delta = delta
        self.label = label
        self.type = type
        self.orderId = orderId
        self.trackingId = trackingId
        self.balanceAfter = balanceAfter
    }

    var isEarned: Bool { delta > 0 }

    var formattedDelta: String {
        delta > 0 ? "+\(delta) pts" : "\(delta) pts"
    }

    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

@MainActor
final class PointsManager: ObservableObject {

    static let shared = PointsManager()

    /// Maximum history entries kept on device. History is newest-first,
    /// so trimming drops the oldest; this keeps the UserDefaults payload
    /// small no matter how many orders a customer places.
    static let maxHistoryEntries = 100

    @Published private(set) var points: Int = 0
    @Published private(set) var history: [PointsTransaction] = []
    @Published private(set) var rules: LoyaltyPointsRules = .default
    /// The balance in dollars, as the server reports it.
    @Published private(set) var balanceValue: Double = 0
    @Published private(set) var lifetimeEarned: Int = 0
    @Published private(set) var lifetimeRedeemed: Int = 0
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String? = nil

    /// The balance in dollars, from the balance and the server rules.
    var pointsValue: Double {
        Double(points) / Double(rules.pointsPerDollar)
    }

    var formattedBalanceValue: String {
        String(format: "$%.2f", balanceValue)
    }

    /// The dollar value of the minimum redemption (minRedeemPoints).
    var minRedemptionValue: Double {
        Double(rules.minRedeemPoints) / Double(rules.pointsPerDollar)
    }

    var formattedMinRedemptionValue: String {
        String(format: "$%.2f", minRedemptionValue)
    }

    /// A negative balance (possible after reversals) cannot be redeemed.
    var canRedeem: Bool { points >= rules.minRedeemPoints }

    var pointsToNextReward: Int { max(0, rules.minRedeemPoints - points) }

    var progressToReward: Double {
        guard rules.minRedeemPoints > 0 else { return 0 }
        return min(1, Double(points) / Double(rules.minRedeemPoints))
    }

    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadCachedSummary()
        // Points belong to the signed-in account; reload when it changes.
        SessionManager.shared.$currentUser
            .map { $0?.id }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadCachedSummary()
                Task { await self?.refresh() }
            }
            .store(in: &cancellables)
    }

    private var userId: Int {
        SessionManager.shared.currentUser?.id ?? 0
    }

    private var summaryKey: String {
        "grocart.points.summary.\(userId)"
    }

    private var lastSeenEarnedKey: String {
        "grocart.points.lastSeenEarned.\(userId)"
    }

    // MARK: - Cache

    private func loadCachedSummary() {
        guard let data = UserDefaults.standard.data(forKey: summaryKey),
              let summary = try? JSONDecoder().decode(LoyaltyPointsSummary.self, from: data) else {
            applySummary(nil)
            return
        }
        applySummary(summary)
    }

    private func cacheSummary(_ summary: LoyaltyPointsSummary) {
        if let data = try? JSONEncoder().encode(summary) {
            UserDefaults.standard.set(data, forKey: summaryKey)
        }
    }

    private func applySummary(_ summary: LoyaltyPointsSummary?) {
        guard let summary = summary else {
            points = 0
            history = []
            rules = .default
            balanceValue = 0
            lifetimeEarned = 0
            lifetimeRedeemed = 0
            return
        }
        points = summary.balance
        rules = summary.rules
        balanceValue = summary.balanceValue
        lifetimeEarned = summary.lifetimeEarned
        lifetimeRedeemed = summary.lifetimeRedeemed
        history = Self.displayTransactions(from: summary.transactions)
    }

    // MARK: - Fetch

    /// Fetches the latest balance and history from the backend. On
    /// failure the last-known summary stays in place, so the points
    /// pill never flashes to zero offline.
    func refresh() async {
        guard SessionManager.shared.currentUser != nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let summary = try await PointsRepository.shared.fetchPoints()
            applySummary(summary)
            cacheSummary(summary)
            checkForNewEarnedPoints(summary)
            lastError = nil
        } catch {
            lastError = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Server → display mapping

    /// EXTENSION POINT: the single place server transactions become
    /// the rows the UI shows. A new server transaction type only needs
    /// a case in PointsTransactionType — the label comes from the
    /// server's own description, so no row text is hard-coded here.
    static func displayTransactions(from transactions: [LoyaltyPointsTransaction]) -> [PointsTransaction] {
        Array(transactions.prefix(maxHistoryEntries).map { tx in
            PointsTransaction(
                id: tx.id,
                date: tx.date,
                delta: tx.points,
                label: tx.description,
                type: tx.type,
                orderId: tx.orderId,
                trackingId: tx.trackingId,
                balanceAfter: tx.balanceAfter
            )
        })
    }

    // MARK: - Earned-points notification

    /// Posts a notification when a new EARNED transaction appears.
    /// The newest earned transaction id is remembered per account, so
    /// each earning notifies once. Points land on delivery, so this is
    /// how the customer learns their order earned points — not at
    /// payment time.
    private func checkForNewEarnedPoints(_ summary: LoyaltyPointsSummary) {
        guard let newest = summary.transactions.first(where: { $0.type == .earned }) else { return }
        if UserDefaults.standard.object(forKey: lastSeenEarnedKey) == nil {
            // First fetch for this account: remember where we are, but
            // do not notify about earnings that predate the app knowing.
            UserDefaults.standard.set(newest.id, forKey: lastSeenEarnedKey)
            return
        }
        let lastSeen = UserDefaults.standard.integer(forKey: lastSeenEarnedKey)
        guard newest.id != lastSeen else { return }
        UserDefaults.standard.set(newest.id, forKey: lastSeenEarnedKey)
        NotificationManager.shared.post(
            type: .points,
            title: "You earned \(newest.points) points",
            message: "\(newest.description) You now have \(summary.balance) points."
        )
    }
}
