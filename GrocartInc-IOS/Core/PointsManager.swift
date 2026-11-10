//
//  PointsManager.swift
//  GrocartInc-IOS
//
//  Rewards points: each item earns points equal to its price rounded to
//  the nearest whole dollar ($4.99 -> 5 pts, $4.20 -> 4 pts), times how
//  many were bought. 500 points can be redeemed for $5 off an order.
//  Every new account starts with a 500-point welcome bonus, so they can
//  use a $5 reward right away or bank it for later.
//  Points and their history are stored on this device, keyed by the
//  signed-in account. There is no loyalty endpoint on the backend yet,
//  so the balance does not sync across devices and is lost if the app
//  data is cleared.
//

import Foundation
import Combine

struct PointsTransaction: Codable, Identifiable {
    let id: UUID
    let date: Date
    /// Points gained (+) or spent (-).
    let delta: Int
    /// e.g. "Order ABC123" or "Redeemed $5 off".
    let label: String

    init(delta: Int, label: String, date: Date = Date(), id: UUID = UUID()) {
        self.id = id
        self.date = date
        self.delta = delta
        self.label = label
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

    /// Points needed to unlock a reward.
    static let redeemThreshold = 500
    /// The discount a reward is worth.
    static let redeemValue: Double = 5.0
    /// Welcome bonus: every new account starts with 500 points — enough
    /// for one $5 reward right away, or to bank for later.
    static let welcomeBonus = 500

    /// Maximum history entries kept on device. History is newest-first,
    /// so trimming drops the oldest; this keeps the UserDefaults payload
    /// small no matter how many orders a customer places.
    static let maxHistoryEntries = 100

    @Published private(set) var points: Int = 0
    @Published private(set) var history: [PointsTransaction] = []

    var canRedeem: Bool { points >= Self.redeemThreshold }

    var pointsToNextReward: Int { max(0, Self.redeemThreshold - points) }

    var progressToReward: Double {
        min(1, Double(points) / Double(Self.redeemThreshold))
    }

    private var cancellables = Set<AnyCancellable>()

    private init() {
        load()
        // Points belong to the signed-in account; reload when it changes.
        SessionManager.shared.$currentUser
            .map { $0?.id }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.load() }
            .store(in: &cancellables)
    }

    private var pointsKey: String {
        "grocart.points.\(SessionManager.shared.currentUser?.id ?? 0)"
    }

    private var historyKey: String {
        "grocart.points.history.\(SessionManager.shared.currentUser?.id ?? 0)"
    }

    private func load() {
        // A new account (no points record yet) starts with the welcome
        // bonus. The key check — not the value — is what makes this
        // one-time: someone who spends their points down to 0 still has
        // a record, so they are not topped up again.
        if SessionManager.shared.currentUser != nil,
           UserDefaults.standard.object(forKey: pointsKey) == nil {
            points = Self.welcomeBonus
            history = [PointsTransaction(delta: Self.welcomeBonus, label: "Welcome bonus")]
            save()
            NotificationManager.shared.post(
                type: .points,
                title: "Welcome bonus: 500 points",
                message: "You started with 500 points — enough for $5 off your first order, or bank them for later."
            )
            return
        }
        points = UserDefaults.standard.integer(forKey: pointsKey)
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let saved = try? JSONDecoder().decode([PointsTransaction].self, from: data) {
            // Trim any oversized history saved before the cap existed.
            history = Array(saved.prefix(Self.maxHistoryEntries))
        } else {
            history = []
        }
    }

    private func save() {
        // Keep history bounded: newest-first, so the prefix keeps the newest.
        if history.count > Self.maxHistoryEntries {
            history = Array(history.prefix(Self.maxHistoryEntries))
        }
        UserDefaults.standard.set(points, forKey: pointsKey)
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    /// Points for one item: its price rounded to the nearest whole dollar,
    /// times how many were bought. $4.99 -> 5, $4.20 -> 4.
    static func points(forPrice price: Double, quantity: Int) -> Int {
        Int(price.rounded()) * quantity
    }

    /// Settles a completed order: if the customer redeemed a reward, take
    /// 500 points, then award the points earned on this order's items.
    /// Returns the points earned on this order.
    @discardableResult
    func settleOrder(earnedPoints: Int, redeemed: Bool, orderLabel: String?) -> Int {
        if redeemed && canRedeem {
            points -= Self.redeemThreshold
            history.insert(PointsTransaction(delta: -Self.redeemThreshold, label: "Redeemed $5 off"), at: 0)
        }
        if earnedPoints > 0 {
            points += earnedPoints
            history.insert(PointsTransaction(delta: earnedPoints, label: orderLabel ?? "Order"), at: 0)
            NotificationManager.shared.post(
                type: .points,
                title: "You earned \(earnedPoints) points",
                message: "Your \(orderLabel ?? "order") earned \(earnedPoints) points. You now have \(points) points."
            )
        }
        save()
        return earnedPoints
    }
}
