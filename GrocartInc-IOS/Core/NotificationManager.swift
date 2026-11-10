//
//  NotificationManager.swift
//  GrocartInc-IOS
//
//  The in-app notification inbox (the bell on Home). Notifications are
//  stored on this device and shown in NotificationsView. The manager is
//  also the place that detects changes worth telling the customer
//  about, by comparing what the app just fetched with a snapshot of
//  what it had seen before:
//    • New products added to a catalogue
//    • A product's price or discount changing
//    • An order moving through placed → processing → in transit →
//      delivered (or cancelled)
//  Points and scratch-card wins post from PointsManager and
//  ScratchCardManager. There is no push backend yet, so these are
//  detected when the app loads the catalogue or the orders — a change
//  shows up the next time the app fetches that list, not instantly
//  while the app is closed.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Notification Type

enum NotificationType: String, Codable {
    case order
    case promo
    case delivery
    case system
    case product    // a new product was added
    case price      // a price or discount changed
    case points     // points were added
    case reward     // a scratch card was won

    var icon: String {
        switch self {
        case .order: return "bag.fill"
        case .promo: return "tag.fill"
        case .delivery: return "truck.box.fill"
        case .system: return "bell.fill"
        case .product: return "basket.fill"
        case .price: return "dollarsign.circle.fill"
        case .points: return "star.fill"
        case .reward: return "gift.fill"
        }
    }

    var color: Color {
        switch self {
        case .order: return Color(red: 0.18, green: 0.72, blue: 0.47)
        case .promo: return .orange
        case .delivery: return Color(red: 0.25, green: 0.55, blue: 0.95)
        case .system: return .purple
        case .product: return .grocartGreen
        case .price: return .orange
        case .points: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .reward: return .purple
        }
    }
}

// MARK: - Notification

/// Everything needed to open a product page from a notification.
struct ProductLink: Codable, Hashable {
    let product: Product
    let store: Store
    let categoryName: String
}

struct AppNotification: Codable, Identifiable {
    let id: UUID
    let type: NotificationType
    let title: String
    let message: String
    let date: Date
    var isRead: Bool
    /// Set for new-product and price-change notifications, so tapping
    /// one opens that product's page.
    let productLink: ProductLink?

    init(id: UUID = UUID(), type: NotificationType, title: String, message: String, date: Date = Date(), isRead: Bool = false, productLink: ProductLink? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.date = date
        self.isRead = isRead
        self.productLink = productLink
    }

    /// Relative display time, e.g. "Just now", "5 min ago", "2 hours ago".
    var time: String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 {
            let m = Int(seconds / 60)
            return "\(m) min ago"
        }
        if seconds < 86400 {
            let h = Int(seconds / 3600)
            return "\(h) hour\(h == 1 ? "" : "s") ago"
        }
        let day = Int(seconds / 86400)
        if day == 1 { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}

// MARK: - Order Stage (canonical, for change detection)

/// The customer-facing stage of an order. Both order models map onto
/// this, so the same order seen through the Orders list and through
/// the Home active-orders list produces one notification, not two.
enum OrderStage: String, Codable {
    case placed
    case processing
    case readyForPickup
    case inTransit
    case delivered
    case cancelled

    var title: String {
        switch self {
        case .placed: return "Order placed"
        case .processing: return "Order processing"
        case .readyForPickup: return "Ready for pickup"
        case .inTransit: return "Order in transit"
        case .delivered: return "Order delivered"
        case .cancelled: return "Order cancelled"
        }
    }

    func message(trackingId: String) -> String {
        switch self {
        case .placed:
            return "Your order \(trackingId) has been placed."
        case .processing:
            return "Your order \(trackingId) is being prepared."
        case .readyForPickup:
            return "Your order \(trackingId) is ready for pickup."
        case .inTransit:
            return "Your order \(trackingId) is on its way."
        case .delivered:
            return "Your order \(trackingId) has been delivered."
        case .cancelled:
            return "Your order \(trackingId) was cancelled."
        }
    }
}

// MARK: - Product Snapshot

/// What the app last saw for one product, so a new product or a price
/// or discount change can be spotted the next time a catalogue loads.
private struct ProductSnapshot: Codable {
    let name: String
    let originalPrice: Double
    let offerPrice: Double?
}

// MARK: - Manager

@MainActor
final class NotificationManager: ObservableObject {

    static let shared = NotificationManager()

    @Published private(set) var notifications: [AppNotification] = []

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    private var cancellables = Set<AnyCancellable>()

    private init() {
        load()
        // Notifications belong to the signed-in account; reload when it changes.
        SessionManager.shared.$currentUser
            .map { $0?.id }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.load() }
            .store(in: &cancellables)
    }

    private var userId: Int {
        SessionManager.shared.currentUser?.id ?? 0
    }

    private var notificationsKey: String {
        "grocart.notifications.\(userId)"
    }

    /// The product snapshot is per device, not per account — the
    /// catalogue is the same for everyone, so a product seen once
    /// should not notify again for another account on this device.
    private var productSnapshotKey: String {
        "grocart.productSnapshot"
    }

    private var orderSnapshotKey: String {
        "grocart.orderSnapshot.\(userId)"
    }

    // MARK: - Storage

    private func load() {
        if let data = UserDefaults.standard.data(forKey: notificationsKey),
           let saved = try? JSONDecoder().decode([AppNotification].self, from: data) {
            notifications = saved
        } else {
            notifications = []
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(data, forKey: notificationsKey)
        }
    }

    // MARK: - Posting

    func post(type: NotificationType, title: String, message: String, productLink: ProductLink? = nil) {
        let notification = AppNotification(type: type, title: title, message: message, productLink: productLink)
        notifications.insert(notification, at: 0)
        // Keep the inbox bounded.
        if notifications.count > 200 {
            notifications = Array(notifications.prefix(200))
        }
        save()
    }

    // MARK: - Read / Delete

    func markAsRead(id: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[index].isRead = true
        save()
    }

    func markAllRead() {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        save()
    }

    func delete(id: UUID) {
        notifications.removeAll { $0.id == id }
        save()
    }

    func clearRead() {
        notifications.removeAll { $0.isRead }
        save()
    }

    // MARK: - Product Changes

    /// Compare a freshly loaded catalogue with the snapshot. A product
    /// id never seen before is a new product; an id whose price or
    /// offer changed is a price/discount change. Each change notifies
    /// once, because the snapshot is updated right away. The product,
    /// its store and category travel with the notification so tapping
    /// it opens that product's page.
    func checkProducts(_ items: [(product: Product, store: Store, categoryName: String)]) {
        var snapshot = loadProductSnapshot()
        for item in items {
            let product = item.product
            let link = ProductLink(product: product, store: item.store, categoryName: item.categoryName)
            if let previous = snapshot[product.id] {
                if previous.originalPrice != product.originalPrice {
                    post(
                        type: .price,
                        title: "Price change: \(product.name)",
                        message: "\(product.name) is now \(formatPrice(product.originalPrice)) (was \(formatPrice(previous.originalPrice))).",
                        productLink: link
                    )
                } else if previous.offerPrice != product.offerPrice {
                    if let offer = product.offerPrice, offer < product.originalPrice {
                        post(
                            type: .price,
                            title: "New discount: \(product.name)",
                            message: "\(product.name) is now \(formatPrice(offer)) (was \(formatPrice(product.originalPrice))).",
                            productLink: link
                        )
                    } else if previous.offerPrice != nil && product.offerPrice == nil {
                        post(
                            type: .price,
                            title: "Discount ended: \(product.name)",
                            message: "\(product.name) is back to \(formatPrice(product.originalPrice)).",
                            productLink: link
                        )
                    }
                }
            } else {
                post(
                    type: .product,
                    title: "New product: \(product.name)",
                    message: "\(product.name) is now available for \(formatPrice(product.displayPrice)).",
                    productLink: link
                )
            }
            snapshot[product.id] = ProductSnapshot(
                name: product.name,
                originalPrice: product.originalPrice,
                offerPrice: product.offerPrice
            )
        }
        saveProductSnapshot(snapshot)
    }

    private func loadProductSnapshot() -> [Int: ProductSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: productSnapshotKey),
              let saved = try? JSONDecoder().decode([Int: ProductSnapshot].self, from: data) else {
            return [:]
        }
        return saved
    }

    private func saveProductSnapshot(_ snapshot: [Int: ProductSnapshot]) {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: productSnapshotKey)
        }
    }

    private func formatPrice(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }

    // MARK: - Order Status Changes

    /// Compare freshly loaded orders with the snapshot. A new order
    /// notifies as placed; an order whose stage changed notifies with
    /// the new stage. Each change notifies once.
    func checkOrders(_ orders: [(id: Int, trackingId: String, stage: OrderStage)]) {
        var snapshot = loadOrderSnapshot()
        for order in orders {
            if let previousRaw = snapshot[order.id],
               let previous = OrderStage(rawValue: previousRaw) {
                if previous != order.stage {
                    post(
                        type: .order,
                        title: order.stage.title,
                        message: order.stage.message(trackingId: order.trackingId)
                    )
                }
            } else {
                // First time this order is seen — it was just placed.
                post(
                    type: .order,
                    title: OrderStage.placed.title,
                    message: OrderStage.placed.message(trackingId: order.trackingId)
                )
            }
            snapshot[order.id] = order.stage.rawValue
        }
        saveOrderSnapshot(snapshot)
    }

    private func loadOrderSnapshot() -> [Int: String] {
        guard let data = UserDefaults.standard.data(forKey: orderSnapshotKey),
              let saved = try? JSONDecoder().decode([Int: String].self, from: data) else {
            return [:]
        }
        return saved
    }

    private func saveOrderSnapshot(_ snapshot: [Int: String]) {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: orderSnapshotKey)
        }
    }
}
