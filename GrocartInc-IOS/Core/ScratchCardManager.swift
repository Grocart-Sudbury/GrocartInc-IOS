//
//  ScratchCardManager.swift
//  GrocartInc-IOS
//
//  Random scratch-card coupons. After every eligible purchase (a
//  successful order) the customer earns one scratch card with a random
//  gift — or nothing at all. New accounts also get one welcome card.
//  Prizes:
//    • 10%–20% off products (random percent, max 20%)
//    • $1–$5 off (random amount, max $5)
//    • $25 off jackpot — rare, only 1% of cards
//    • "Better luck next time" (no prize)
//  Not everyone wins: 39% of cards are "better luck next time".
//  Cards are stored on this device, keyed by the signed-in account,
//  like points. There is no scratch-card endpoint on the backend yet,
//  so cards do not sync across devices and are lost if the app data
//  is cleared. A scratched winning card is applied at checkout as a
//  local discount (same as the points discount), not as a backend
//  promo code.
//

import Foundation
import Combine
import SwiftUI

struct ScratchCard: Codable, Identifiable {
    enum Kind: String, Codable {
        case percent   // 10–20% off products
        case fixed     // $1–$5 off
        case jackpot   // $25 off — rare, 1% of cards
        case none      // Better luck next time
    }

    let id: UUID
    let date: Date
    let orderLabel: String?
    let kind: Kind
    /// Percent (10–20) for .percent, dollars (1–5) for .fixed,
    /// 25 for .jackpot, 0 for .none.
    let value: Double
    var isScratched: Bool
    var isUsed: Bool
    let expiresAt: Date
    /// Display code, e.g. SCRATCH-AB12CD. For reference only — local
    /// cards are applied at checkout by selecting them, not by typing
    /// this code (the backend does not know it).
    let code: String

    var isWinner: Bool { kind != .none }

    var isExpired: Bool { Date() > expiresAt }

    /// Usable at checkout: scratched, a winner, not used, not expired.
    var isUsable: Bool { isScratched && isWinner && !isUsed && !isExpired }

    var displayDiscount: String {
        switch kind {
        case .percent:
            return "\(Int(value))% OFF"
        case .fixed:
            let str = value.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", value)
                : String(format: "%.2f", value)
            return "$\(str) OFF"
        case .jackpot:
            return "$25 OFF"
        case .none:
            return "Better luck next time"
        }
    }

    var displayDescription: String {
        switch kind {
        case .percent:
            return "Save \(Int(value))% on products"
        case .fixed:
            let str = value.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", value)
                : String(format: "%.2f", value)
            return "Save $\(str) on your order"
        case .jackpot:
            return "Jackpot! Save $25 on your order"
        case .none:
            return "No prize this time — try again on your next order"
        }
    }

    var gradientColors: [Color] {
        switch kind {
        case .percent:
            return [Color.orange, Color.red]
        case .fixed:
            return [Color(red: 0.18, green: 0.8, blue: 0.44), Color(red: 0.09, green: 0.63, blue: 0.52)]
        case .jackpot:
            return [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 0.56, green: 0.27, blue: 0.68)]
        case .none:
            return [Color.gray, Color(red: 0.35, green: 0.35, blue: 0.4)]
        }
    }

    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    var formattedExpiry: String {
        expiresAt.formatted(date: .abbreviated, time: .omitted)
    }
}

@MainActor
final class ScratchCardManager: ObservableObject {

    static let shared = ScratchCardManager()

    /// How long a scratch card stays valid after it is earned.
    static let validityDays = 30

    /// Maximum cards kept on device. Cards are newest-first, so trimming
    /// drops the oldest; expired cards are pruned on load.
    static let maxCards = 50

    @Published private(set) var cards: [ScratchCard] = []

    /// Scratched winners that can be applied at checkout.
    var availableCards: [ScratchCard] {
        cards.filter { $0.isUsable }
    }

    private var cancellables = Set<AnyCancellable>()

    private init() {
        load()
        // Cards belong to the signed-in account; reload when it changes.
        SessionManager.shared.$currentUser
            .map { $0?.id }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.load() }
            .store(in: &cancellables)
    }

    private var cardsKey: String {
        "grocart.scratchcards.\(SessionManager.shared.currentUser?.id ?? 0)"
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: cardsKey),
           let saved = try? JSONDecoder().decode([ScratchCard].self, from: data) {
            cards = saved
        } else {
            cards = []
        }

        // Prune expired cards and cap the list so it never grows forever.
        // Cards are newest-first, so the prefix keeps the newest.
        cards.removeAll { $0.isExpired }
        if cards.count > Self.maxCards {
            cards = Array(cards.prefix(Self.maxCards))
        }

        // Welcome bonus: a new account (no cards record yet) gets one
        // guaranteed-winning scratch card. The key check — not the count —
        // is what makes this one-time.
        if SessionManager.shared.currentUser != nil,
           UserDefaults.standard.object(forKey: cardsKey) == nil {
            let welcome = Self.welcomeCard()
            cards = [welcome]
            save()
        }
    }

    private func save() {
        // Keep the list bounded: newest-first, so the prefix keeps the newest.
        if cards.count > Self.maxCards {
            cards = Array(cards.prefix(Self.maxCards))
        }
        if let data = try? JSONEncoder().encode(cards) {
            UserDefaults.standard.set(data, forKey: cardsKey)
        }
    }

    // MARK: - Generation

    /// One random scratch card after an eligible purchase. 1% of cards
    /// are a $25 jackpot; 39% are "better luck next time" — not
    /// everyone wins.
    @discardableResult
    func generateAfterOrder(orderLabel: String?) -> ScratchCard {
        let card = Self.randomCard(orderLabel: orderLabel)
        cards.insert(card, at: 0)
        save()
        return card
    }

    private static func randomCard(orderLabel: String?) -> ScratchCard {
        let roll = Double.random(in: 0..<1)
        let kind: ScratchCard.Kind
        let value: Double
        if roll < 0.01 {
            kind = .jackpot
            value = 25
        } else if roll < 0.40 {
            kind = .none
            value = 0
        } else if roll < 0.75 {
            kind = .percent
            value = Double(Int.random(in: 10...20))
        } else {
            kind = .fixed
            value = Double(Int.random(in: 1...5))
        }
        return makeCard(kind: kind, value: value, orderLabel: orderLabel)
    }

    /// The welcome card is always a winner — a random percent or
    /// fixed discount — never "better luck next time".
    private static func welcomeCard() -> ScratchCard {
        if Bool.random() {
            return makeCard(kind: .percent, value: Double(Int.random(in: 10...20)), orderLabel: "Welcome bonus")
        } else {
            return makeCard(kind: .fixed, value: Double(Int.random(in: 1...5)), orderLabel: "Welcome bonus")
        }
    }

    private static func makeCard(kind: ScratchCard.Kind, value: Double, orderLabel: String?) -> ScratchCard {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let suffix = String((0..<6).map { _ in letters.randomElement() ?? "A" })
        return ScratchCard(
            id: UUID(),
            date: Date(),
            orderLabel: orderLabel,
            kind: kind,
            value: value,
            isScratched: false,
            isUsed: false,
            expiresAt: Date().addingTimeInterval(TimeInterval(validityDays * 24 * 60 * 60)),
            code: "SCRATCH-\(suffix)"
        )
    }

    // MARK: - State

    func markScratched(_ card: ScratchCard) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[index].isScratched = true
        save()
        if card.isWinner {
            NotificationManager.shared.post(
                type: .reward,
                title: "Scratch card win: \(card.displayDiscount)",
                message: "You won \(card.displayDiscount) on your scratch card. Use it at checkout before it expires on \(card.formattedExpiry)."
            )
        }
    }

    func markUsed(_ card: ScratchCard) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[index].isUsed = true
        save()
    }

    // MARK: - Discount

    /// The discount a card is worth on this order. Percent cards take
    /// their percent off the products subtotal; fixed and jackpot cards
    /// take their dollars off, capped at the subtotal so the total never
    /// goes below $0 on this card alone.
    static func discount(for card: ScratchCard, subtotal: Double) -> Double {
        switch card.kind {
        case .percent:
            return subtotal * (card.value / 100.0)
        case .fixed, .jackpot:
            return min(card.value, subtotal)
        case .none:
            return 0
        }
    }
}
