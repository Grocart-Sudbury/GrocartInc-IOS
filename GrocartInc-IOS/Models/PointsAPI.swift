//
//  PointsAPI.swift
//  GrocartInc-IOS
//
//  Server models for the backend loyalty API
//  (Grocart_Loyalty_Points_API.pdf, v1.0, staging commit 10395e8).
//
//  Rules (from the server; the values in `LoyaltyPointsRules.default`
//  are fallback defaults, used only until the first fetch):
//    • 100 points = $1.00
//    • Earn 1 point per $1 of item subtotal after discounts, rounded
//      down (tax, delivery, service fee and tip earn nothing)
//    • Redeem any amount from 100 points up, on orders with a
//      subtotal of $30.00 or more
//    • Points land when the order is DELIVERED and payment is PAID
//    • Welcome bonus: 500 points once per account — granted at
//      registration, and to every existing account the first time
//      they fetch their points (configurable on the server as
//      points.welcome-bonus)
//    • Points CAN be combined with coupons and bundle deals: the
//      coupon/bundle discount applies first, points cover the rest
//      of the subtotal; no expiry; the balance can go negative on
//      reversals
//
//  The app never hard-codes a rule value — it reads `rules` from the
//  summary. A new server transaction type only needs a case in
//  PointsTransactionType; decoding never breaks on an unknown type.
//

import Foundation

// MARK: - Rules

/// The redemption/earning rules, as returned by the server.
struct LoyaltyPointsRules: Codable {
    let pointsPerDollar: Int
    let earnPointsPerDollar: Int
    let minRedeemPoints: Int
    let minOrderSubtotal: Double
    /// One-time grant when the account is created.
    let welcomeBonusPoints: Int

    /// Fallback defaults matching the server. Used only until the first
    /// fetch returns the server's own rules.
    static let `default` = LoyaltyPointsRules(
        pointsPerDollar: 100,
        earnPointsPerDollar: 1,
        minRedeemPoints: 100,
        minOrderSubtotal: 0.0,
        welcomeBonusPoints: 500
    )

    init(pointsPerDollar: Int, earnPointsPerDollar: Int, minRedeemPoints: Int, minOrderSubtotal: Double, welcomeBonusPoints: Int) {
        self.pointsPerDollar = pointsPerDollar
        self.earnPointsPerDollar = earnPointsPerDollar
        self.minRedeemPoints = minRedeemPoints
        self.minOrderSubtotal = minOrderSubtotal
        self.welcomeBonusPoints = welcomeBonusPoints
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Self.default
        pointsPerDollar = try container.decodeIfPresent(Int.self, forKey: .pointsPerDollar) ?? fallback.pointsPerDollar
        earnPointsPerDollar = try container.decodeIfPresent(Int.self, forKey: .earnPointsPerDollar) ?? fallback.earnPointsPerDollar
        minRedeemPoints = try container.decodeIfPresent(Int.self, forKey: .minRedeemPoints) ?? fallback.minRedeemPoints
        minOrderSubtotal = try container.decodeIfPresent(Double.self, forKey: .minOrderSubtotal) ?? fallback.minOrderSubtotal
        welcomeBonusPoints = try container.decodeIfPresent(Int.self, forKey: .welcomeBonusPoints) ?? fallback.welcomeBonusPoints
    }
}

// MARK: - Transaction Type

/// Server transaction types. `unknown` is the fallback so a type the
/// server adds later never breaks decoding.
enum PointsTransactionType: Codable, Equatable {
    case earned
    case welcomeBonus
    case redeemed
    case redemptionReturned
    case earnedReversed
    case adminAdjustment
    case unknown(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "EARNED": self = .earned
        case "WELCOME_BONUS": self = .welcomeBonus
        case "REDEEMED": self = .redeemed
        case "REDEMPTION_RETURNED": self = .redemptionReturned
        case "EARNED_REVERSED": self = .earnedReversed
        case "ADMIN_ADJUSTMENT": self = .adminAdjustment
        default: self = .unknown(raw)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var rawValue: String {
        switch self {
        case .earned: return "EARNED"
        case .welcomeBonus: return "WELCOME_BONUS"
        case .redeemed: return "REDEEMED"
        case .redemptionReturned: return "REDEMPTION_RETURNED"
        case .earnedReversed: return "EARNED_REVERSED"
        case .adminAdjustment: return "ADMIN_ADJUSTMENT"
        case .unknown(let raw): return raw
        }
    }

    /// Customer-facing label for the history list.
    var displayLabel: String {
        switch self {
        case .earned: return "Earned"
        case .welcomeBonus: return "Welcome bonus"
        case .redeemed: return "Redeemed"
        case .redemptionReturned: return "Returned"
        case .earnedReversed: return "Reversed"
        case .adminAdjustment: return "Adjustment"
        case .unknown(let raw): return raw
        }
    }
}

// MARK: - Transaction

struct LoyaltyPointsTransaction: Codable {
    let id: Int
    let type: PointsTransactionType
    /// Signed change: positive adds, negative removes.
    let points: Int
    let balanceAfter: Int
    let description: String
    let createdBy: String
    /// Server local time, ISO-8601 without a zone
    /// ("2026-11-10T18:22:05").
    let createdAt: String
    let orderId: Int?
    let trackingId: String?

    init(id: Int, type: PointsTransactionType, points: Int, balanceAfter: Int, description: String, createdBy: String, createdAt: String, orderId: Int? = nil, trackingId: String? = nil) {
        self.id = id
        self.type = type
        self.points = points
        self.balanceAfter = balanceAfter
        self.description = description
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.orderId = orderId
        self.trackingId = trackingId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        type = try container.decode(PointsTransactionType.self, forKey: .type)
        points = try container.decode(Int.self, forKey: .points)
        balanceAfter = try container.decodeIfPresent(Int.self, forKey: .balanceAfter) ?? 0
        description = try container.decode(String.self, forKey: .description)
        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy) ?? ""
        createdAt = try container.decode(String.self, forKey: .createdAt)
        orderId = try container.decodeIfPresent(Int.self, forKey: .orderId)
        trackingId = try container.decodeIfPresent(String.self, forKey: .trackingId)
    }

    /// Parsed from `createdAt`. The server sends LocalDateTime without
    /// a zone; ISO-8601 with a zone is accepted too.
    var date: Date {
        Self.parseDate(createdAt) ?? Date()
    }

    // MARK: - Date parsing (two-formatter pattern, as in CustomerOrder)

    private static let localDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func parseDate(_ string: String) -> Date? {
        if let date = localDateTimeFormatter.date(from: string) { return date }
        return iso8601Formatter.date(from: string)
    }
}

// MARK: - Summary

struct LoyaltyPointsSummary: Codable {
    let customerId: Int
    let customerName: String
    let customerEmail: String
    let balance: Int
    /// Balance in CAD (balance / pointsPerDollar).
    let balanceValue: Double
    let lifetimeEarned: Int
    let lifetimeRedeemed: Int
    let rules: LoyaltyPointsRules
    /// Newest first.
    let transactions: [LoyaltyPointsTransaction]

    init(customerId: Int, customerName: String, customerEmail: String, balance: Int, balanceValue: Double, lifetimeEarned: Int, lifetimeRedeemed: Int, rules: LoyaltyPointsRules, transactions: [LoyaltyPointsTransaction]) {
        self.customerId = customerId
        self.customerName = customerName
        self.customerEmail = customerEmail
        self.balance = balance
        self.balanceValue = balanceValue
        self.lifetimeEarned = lifetimeEarned
        self.lifetimeRedeemed = lifetimeRedeemed
        self.rules = rules
        self.transactions = transactions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        customerId = try container.decodeIfPresent(Int.self, forKey: .customerId) ?? 0
        customerName = try container.decodeIfPresent(String.self, forKey: .customerName) ?? ""
        customerEmail = try container.decodeIfPresent(String.self, forKey: .customerEmail) ?? ""
        balance = try container.decodeIfPresent(Int.self, forKey: .balance) ?? 0
        rules = try container.decodeIfPresent(LoyaltyPointsRules.self, forKey: .rules) ?? .default
        balanceValue = try container.decodeIfPresent(Double.self, forKey: .balanceValue)
            ?? Double(balance) / Double(rules.pointsPerDollar)
        lifetimeEarned = try container.decodeIfPresent(Int.self, forKey: .lifetimeEarned) ?? 0
        lifetimeRedeemed = try container.decodeIfPresent(Int.self, forKey: .lifetimeRedeemed) ?? 0
        transactions = try container.decodeIfPresent([LoyaltyPointsTransaction].self, forKey: .transactions) ?? []
    }
}
