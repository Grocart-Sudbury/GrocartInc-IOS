//
//  NotificationsView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

//
//  NotificationsView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

// MARK: - Notification Model
struct AppNotification: Identifiable {
    let id = UUID()
    let type: NotificationType
    let title: String
    let message: String
    let time: String
    var isRead: Bool
}

enum NotificationType {
    case order, promo, delivery, system
    
    var icon: String {
        switch self {
        case .order: return "bag.fill"
        case .promo: return "tag.fill"
        case .delivery: return "truck.box.fill"
        case .system: return "bell.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .order: return Color(red: 0.18, green: 0.72, blue: 0.47)
        case .promo: return .orange
        case .delivery: return Color(red: 0.25, green: 0.55, blue: 0.95)
        case .system: return .purple
        }
    }
}

// MARK: - Notifications View
struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notifications: [AppNotification] = [
        AppNotification(type: .delivery, title: "Order Out for Delivery", message: "Your order GC-2026-0847 is on its way. Estimated arrival: 2:00 - 3:00 PM", time: "10 min ago", isRead: false),
        AppNotification(type: .promo, title: "Weekend Flash Sale! ⚡", message: "Get 30% off on all frozen foods this weekend. Use code FROZEN30", time: "1 hour ago", isRead: false),
        AppNotification(type: .order, title: "Order Confirmed", message: "Your order GC-2026-0847 has been confirmed and is being prepared", time: "2 hours ago", isRead: true),
        AppNotification(type: .system, title: "New Feature: Scheduled Delivery", message: "You can now schedule your deliveries up to 7 days in advance!", time: "Yesterday", isRead: true),
        AppNotification(type: .promo, title: "Your Coupon is Expiring Soon", message: "DAIRY10 coupon expires in 3 days. Use it before it's gone!", time: "Yesterday", isRead: true),
        AppNotification(type: .delivery, title: "Order Delivered ✓", message: "Your order GC-2026-0832 was delivered successfully. Rate your experience!", time: "Feb 5", isRead: true),
        AppNotification(type: .order, title: "Price Drop Alert", message: "Organic Bananas are now $1.49/lb — 25% less than your last purchase", time: "Feb 4", isRead: true)
    ]
    
    private var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }
    
    private var todayNotifications: [AppNotification] {
        notifications.filter { $0.time.contains("min") || $0.time.contains("hour") }
    }
    
    private var earlierNotifications: [AppNotification] {
        notifications.filter { !($0.time.contains("min") || $0.time.contains("hour")) }
    }
    
    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()
            
            if notifications.isEmpty {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.08))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.grocartSecondary.opacity(0.4))
                    }
                    
                    Text("No Notifications")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.grocartPrimary)
                    
                    Text("You're all caught up!")
                        .font(.system(size: 14))
                        .foregroundColor(.grocartSecondary)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Unread Banner
                        if unreadCount > 0 {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                
                                Text("\(unreadCount) unread notification\(unreadCount > 1 ? "s" : "")")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.grocartPrimary)
                                
                                Spacer()
                                
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        for i in notifications.indices {
                                            notifications[i].isRead = true
                                        }
                                    }
                                } label: {
                                    Text("Mark all read")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.grocartGreen)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.grocartSecondaryBackground)
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                        
                        // Today Section
                        if !todayNotifications.isEmpty {
                            NotificationSection(
                                title: "Today",
                                notifications: todayNotifications.map { notif in
                                    notifications.first(where: { $0.id == notif.id })!
                                },
                                onTap: { id in markAsRead(id: id) },
                                onDelete: { id in deleteNotification(id: id) }
                            )
                        }
                        
                        // Earlier Section
                        if !earlierNotifications.isEmpty {
                            NotificationSection(
                                title: "Earlier",
                                notifications: earlierNotifications.map { notif in
                                    notifications.first(where: { $0.id == notif.id })!
                                },
                                onTap: { id in markAsRead(id: id) },
                                onDelete: { id in deleteNotification(id: id) }
                            )
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 10)
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.grocartPrimary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if !notifications.isEmpty {
                    Menu {
                        Button(action: {
                            withAnimation {
                                for i in notifications.indices {
                                    notifications[i].isRead = true
                                }
                            }
                        }) {
                            Label("Mark All as Read", systemImage: "checkmark.circle")
                        }
                        
                        Button(role: .destructive, action: {
                            withAnimation {
                                notifications.removeAll(where: { $0.isRead })
                            }
                        }) {
                            Label("Clear Read", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.grocartPrimary)
                    }
                }
            }
        }
    }
    
    private func markAsRead(id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let idx = notifications.firstIndex(where: { $0.id == id }) {
                notifications[idx].isRead = true
            }
        }
    }
    
    private func deleteNotification(id: UUID) {
        withAnimation(.easeInOut(duration: 0.3)) {
            notifications.removeAll { $0.id == id }
        }
    }
}

// MARK: - Notification Section
struct NotificationSection: View {
    let title: String
    let notifications: [AppNotification]
    let onTap: (UUID) -> Void
    let onDelete: (UUID) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.grocartSecondary)
                .tracking(1)
                .padding(.horizontal, 20)
            
            VStack(spacing: 2) {
                ForEach(notifications) { notification in
                    NotificationRow(notification: notification) {
                        onTap(notification.id)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onDelete(notification.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .background(Color.grocartSecondaryBackground)
            .cornerRadius(16)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Notification Row
struct NotificationRow: View {
    let notification: AppNotification
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(notification.type.color.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: notification.type.icon)
                        .font(.system(size: 16))
                        .foregroundColor(notification.type.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.system(size: 14, weight: notification.isRead ? .medium : .semibold))
                            .foregroundColor(.grocartPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(notification.time)
                            .font(.system(size: 11))
                            .foregroundColor(.grocartSecondary)
                    }
                    
                    Text(notification.message)
                        .font(.system(size: 12))
                        .foregroundColor(.grocartSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                if !notification.isRead {
                    Circle()
                        .fill(notification.type.color)
                        .frame(width: 8, height: 8)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(notification.isRead ? Color.clear : notification.type.color.opacity(0.03))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
    }
}
