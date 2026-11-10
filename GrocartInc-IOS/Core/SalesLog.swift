//
//  SalesLog.swift
//  GrocartInc-IOS
//
//  Monthly sales log: every completed order placed through the app is
//  recorded here on this device, with the store, the category of each
//  item, and the full money breakdown (subtotal, tax, tip, delivery
//  charge, discount, total). The Sales Report screen turns this log
//  into a monthly Excel file.
//
//  The log only covers orders placed through the app on this device,
//  from now on. The backend's customer order endpoints do not return
//  tip, delivery charge, or category, and there is no admin endpoint
//  for all customers' sales, so past orders cannot be backfilled
//  accurately. A complete all-customers report needs a backend admin
//  endpoint.
//

import Foundation
import Combine

/// One item sold, as recorded in the sales log.
struct SalesLogItem: Codable, Identifiable, Sendable {
    let id: UUID
    let productId: Int
    let productName: String
    let categoryName: String
    let quantity: Int
    let unitPrice: Double
    /// unitPrice x quantity.
    let lineTotal: Double

    init(productId: Int, productName: String, categoryName: String, quantity: Int, unitPrice: Double, id: UUID = UUID()) {
        self.id = id
        self.productId = productId
        self.productName = productName
        self.categoryName = categoryName
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.lineTotal = unitPrice * Double(quantity)
    }
}

/// One completed order, as recorded in the sales log.
struct SalesLogEntry: Codable, Identifiable, Sendable {
    let id: UUID
    /// When the order was placed.
    let date: Date
    let orderId: Int
    let trackingId: String
    let storeId: Int
    let storeName: String
    /// "DELIVERY" or "PICKUP".
    let orderType: String
    /// "STRIPE" or "CASH".
    let paymentMethod: String
    let items: [SalesLogItem]
    let subtotal: Double
    let tax: Double
    let deliveryCharge: Double
    let tip: Double
    let discount: Double
    let total: Double

    /// Total number of units sold in this order.
    var itemCount: Int { items.reduce(0) { $0 + $1.quantity } }
}

@MainActor
final class SalesLogManager: ObservableObject {

    static let shared = SalesLogManager()

    /// Maximum entries kept on device. Entries are newest-first, so
    /// trimming drops the oldest; this keeps the UserDefaults payload
    /// small no matter how many orders are placed.
    static let maxEntries = 2000

    @Published private(set) var entries: [SalesLogEntry] = []

    private var cancellables = Set<AnyCancellable>()

    private init() {
        load()
        // The log belongs to the signed-in account; reload when it changes.
        SessionManager.shared.$currentUser
            .map { $0?.id }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.load() }
            .store(in: &cancellables)
    }

    private var entriesKey: String {
        "grocart.saleslog.\(SessionManager.shared.currentUser?.id ?? 0)"
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: entriesKey),
           let saved = try? JSONDecoder().decode([SalesLogEntry].self, from: data) {
            // Trim any oversized log saved before the cap existed.
            entries = Array(saved.prefix(Self.maxEntries))
        } else {
            entries = []
        }
    }

    private func save() {
        // Keep the log bounded: newest-first, so the prefix keeps the newest.
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: entriesKey)
        }
    }

    /// Records a completed order. Call only once per order, and only when
    /// the order actually succeeded (placement for cash, payment for card).
    func recordOrder(
        orderId: Int,
        trackingId: String,
        store: Store,
        items: [CartItem],
        orderType: String,
        paymentMethod: String,
        subtotal: Double,
        tax: Double,
        deliveryCharge: Double,
        tip: Double,
        discount: Double,
        total: Double
    ) {
        let logItems = items.map { item in
            SalesLogItem(
                productId: item.product.id,
                productName: item.product.name,
                categoryName: item.categoryName,
                quantity: item.count,
                unitPrice: item.product.displayPrice
            )
        }
        let entry = SalesLogEntry(
            id: UUID(),
            date: Date(),
            orderId: orderId,
            trackingId: trackingId,
            storeId: store.id,
            storeName: store.name,
            orderType: orderType,
            paymentMethod: paymentMethod,
            items: logItems,
            subtotal: subtotal,
            tax: tax,
            deliveryCharge: deliveryCharge,
            tip: tip,
            discount: discount,
            total: total
        )
        entries.insert(entry, at: 0)
        save()
    }

    /// The entries whose date falls in the same calendar month as `date`.
    func entries(forMonthContaining date: Date) -> [SalesLogEntry] {
        let calendar = Calendar.current
        let target = calendar.dateComponents([.year, .month], from: date)
        return entries.filter {
            let components = calendar.dateComponents([.year, .month], from: $0.date)
            return components.year == target.year && components.month == target.month
        }
    }

    /// The first day of each month that has at least one entry, newest
    /// first. Used for the month picker in the Sales Report screen.
    func availableMonths() -> [Date] {
        let calendar = Calendar.current
        var seen = Set<String>()
        var months: [Date] = []
        for entry in entries {
            let components = calendar.dateComponents([.year, .month], from: entry.date)
            let key = "\(components.year ?? 0)-\(components.month ?? 0)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            if let first = calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1)) {
                months.append(first)
            }
        }
        // Entries are newest-first, so months already come out newest-first;
        // sort explicitly so the order never depends on that.
        return months.sorted(by: >)
    }
}
