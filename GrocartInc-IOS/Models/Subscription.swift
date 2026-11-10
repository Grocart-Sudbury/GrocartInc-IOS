//
//  Subscription.swift
//  GrocartInc-IOS
//
//  Subscriptions: a recurring order from one store, billed on a saved card
//  every week, every 2 weeks, or every month, for delivery or pickup.
//  The backend owns recurring billing (it charges the saved card each
//  cycle); the app creates and manages the subscription record.
//

import Foundation

// MARK: - Subscription frequency
enum SubscriptionFrequency: String, Codable, CaseIterable {
    case weekly = "WEEKLY"
    case biWeekly = "BI_WEEKLY"
    case monthly = "MONTHLY"

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .biWeekly: return "Every 2 weeks"
        case .monthly: return "Monthly"
        }
    }

    /// Days between recurring deliveries. The first delivery is today
    /// (before the cutoff) or tomorrow — not one interval out.
    var daysInterval: Int {
        switch self {
        case .weekly: return 7
        case .biWeekly: return 14
        case .monthly: return 30
        }
    }
}

// MARK: - Subscription item
struct SubscriptionItem: Codable, Identifiable, Hashable {
    let productId: Int
    let productName: String
    let quantity: Int
    let unitPrice: Double
    let imageUrl: String?

    var id: Int { productId }
    var lineTotal: Double { unitPrice * Double(quantity) }
    var formattedLineTotal: String { String(format: "$%.2f", lineTotal) }
    var formattedUnitPrice: String { String(format: "$%.2f", unitPrice) }
}

// MARK: - Subscription status
enum SubscriptionStatus: String, Codable {
    case active = "ACTIVE"
    case paused = "PAUSED"
    case cancelled = "CANCELLED"

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .paused: return "Paused"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - Subscription
struct Subscription: Codable, Identifiable, Hashable {
    let id: Int
    let storeId: Int
    let storeName: String
    let frequency: SubscriptionFrequency
    let fulfilment: OrderType
    let items: [SubscriptionItem]
    let paymentMethodId: String
    let paymentCardLabel: String?
    let addressId: Int?
    let deliveryAddressLabel: String?
    let nextDeliveryDate: String?
    let status: SubscriptionStatus
    let createdAt: String?

    /// Local-only subscriptions use a negative id. They are created
    /// on-device when the backend could not confirm the subscription, so
    /// they are not billed by the backend until they are recreated once
    /// the backend is ready.
    var isLocalOnly: Bool { id < 0 }

    var itemCount: Int { items.reduce(0) { $0 + $1.quantity } }
    var totalPerCycle: Double { items.reduce(0) { $0 + $1.lineTotal } }
    var formattedTotalPerCycle: String { String(format: "$%.2f", totalPerCycle) }

    var formattedNextDelivery: String {
        guard let raw = nextDeliveryDate, !raw.isEmpty else { return "—" }
        return Self.formatBackendDate(raw)
    }

    /// The backend sends dates as strings, either LocalDateTime
    /// ("2026-04-28T10:00:00") or ISO8601. Try both.
    static func formatBackendDate(_ raw: String) -> String {
        let local = DateFormatter()
        local.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = local.date(from: raw) {
            let out = DateFormatter()
            out.dateStyle = .medium
            return out.string(from: date)
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) {
            let out = DateFormatter()
            out.dateStyle = .medium
            return out.string(from: date)
        }
        let iso2 = ISO8601DateFormatter()
        if let date = iso2.date(from: raw) {
            let out = DateFormatter()
            out.dateStyle = .medium
            return out.string(from: date)
        }
        return raw
    }

    /// Format a Date as the backend's LocalDateTime string.
    static func backendDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.string(from: date)
    }

    /// Same-day cutoff (24-hour clock): orders placed before 2 PM are
    /// delivered today, orders placed at or after 2 PM are delivered
    /// tomorrow. The first delivery is that day; later deliveries then
    /// follow the frequency from the first delivery date.
    static let sameDayCutoffHour = 14

    /// The first delivery date for a subscription started now: today
    /// before the cutoff, otherwise tomorrow. Returned at start of day.
    static func firstDeliveryDate(from date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: date)
        if calendar.component(.hour, from: date) < sameDayCutoffHour {
            return startOfToday
        }
        return calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
    }

    // MARK: - Lenient decoding
    // The backend shape is not verified, so every field except the id is
    // read leniently with a sensible default instead of failing the
    // whole list when one field is missing or differently cased.
    private enum CodingKeys: String, CodingKey {
        case id, storeId, storeName, frequency, fulfilment
        case items, paymentMethodId, paymentCardLabel
        case addressId, deliveryAddressLabel
        case nextDeliveryDate, status, createdAt
    }

    init(
        id: Int,
        storeId: Int,
        storeName: String,
        frequency: SubscriptionFrequency,
        fulfilment: OrderType,
        items: [SubscriptionItem],
        paymentMethodId: String,
        paymentCardLabel: String? = nil,
        addressId: Int? = nil,
        deliveryAddressLabel: String? = nil,
        nextDeliveryDate: String? = nil,
        status: SubscriptionStatus = .active,
        createdAt: String? = nil
    ) {
        self.id = id
        self.storeId = storeId
        self.storeName = storeName
        self.frequency = frequency
        self.fulfilment = fulfilment
        self.items = items
        self.paymentMethodId = paymentMethodId
        self.paymentCardLabel = paymentCardLabel
        self.addressId = addressId
        self.deliveryAddressLabel = deliveryAddressLabel
        self.nextDeliveryDate = nextDeliveryDate
        self.status = status
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        storeId = try c.decodeIfPresent(Int.self, forKey: .storeId) ?? 0
        storeName = try c.decodeIfPresent(String.self, forKey: .storeName) ?? ""
        frequency = try c.decodeIfPresent(SubscriptionFrequency.self, forKey: .frequency) ?? .weekly
        if let fulfilmentRaw = try c.decodeIfPresent(String.self, forKey: .fulfilment) {
            fulfilment = OrderType(rawValue: fulfilmentRaw.uppercased()) ?? .delivery
        } else {
            fulfilment = .delivery
        }
        items = try c.decodeIfPresent([SubscriptionItem].self, forKey: .items) ?? []
        paymentMethodId = try c.decodeIfPresent(String.self, forKey: .paymentMethodId) ?? ""
        paymentCardLabel = try c.decodeIfPresent(String.self, forKey: .paymentCardLabel)
        addressId = try c.decodeIfPresent(Int.self, forKey: .addressId)
        deliveryAddressLabel = try c.decodeIfPresent(String.self, forKey: .deliveryAddressLabel)
        nextDeliveryDate = try c.decodeIfPresent(String.self, forKey: .nextDeliveryDate)
        status = try c.decodeIfPresent(SubscriptionStatus.self, forKey: .status) ?? .active
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

// MARK: - Create request
struct CreateSubscriptionRequest: Encodable {
    let storeId: Int
    let frequency: SubscriptionFrequency
    let fulfilment: OrderType
    let items: [Item]
    let paymentMethodId: String
    let addressId: Int?

    struct Item: Encodable {
        let productId: Int
        let quantity: Int
    }

    private enum CodingKeys: String, CodingKey {
        case storeId, frequency, fulfilment, items, paymentMethodId, addressId
    }

    // Only send addressId when one was chosen (pickup has none).
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(storeId, forKey: .storeId)
        try c.encode(frequency, forKey: .frequency)
        try c.encode(fulfilment, forKey: .fulfilment)
        try c.encode(items, forKey: .items)
        try c.encode(paymentMethodId, forKey: .paymentMethodId)
        if let addressId {
            try c.encode(addressId, forKey: .addressId)
        }
    }
}
