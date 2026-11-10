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

// The notification model and types live in NotificationManager
// (Core/NotificationManager.swift) — this view just shows them.

// MARK: - Notifications View
struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var notificationManager = NotificationManager.shared
    @State private var selectedProductLink: ProductLink?
    @State private var isResolvingProduct = false

    private var notifications: [AppNotification] {
        notificationManager.notifications
    }

    private var unreadCount: Int {
        notificationManager.unreadCount
    }

    private var todayNotifications: [AppNotification] {
        notifications.filter { $0.isToday }
    }

    private var earlierNotifications: [AppNotification] {
        notifications.filter { !$0.isToday }
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
                                        notificationManager.markAllRead()
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
                                notifications: todayNotifications,
                                onTap: { id in handleTap(id: id) },
                                onDelete: { id in deleteNotification(id: id) }
                            )
                        }
                        
                        // Earlier Section
                        if !earlierNotifications.isEmpty {
                            NotificationSection(
                                title: "Earlier",
                                notifications: earlierNotifications,
                                onTap: { id in handleTap(id: id) },
                                onDelete: { id in deleteNotification(id: id) }
                            )
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 10)
                }
            }

            // Tapping a new-product or price-change notification opens
            // that product's page. The link is driven by tag/selection:
            // it appears (and pushes) as soon as a product is selected,
            // and popping back clears the selection. (The old hidden
            // isActive link never pushed from inside this NavigationView.)
            if let link = selectedProductLink {
                NavigationLink(
                    destination: ProductDetailView(product: link.product, categoryName: link.categoryName, store: link.store),
                    tag: link,
                    selection: $selectedProductLink,
                    label: { EmptyView() }
                )
                .hidden()
            }

            if isResolvingProduct {
                ProgressView()
                    .scaleEffect(1.3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.25))
                    .ignoresSafeArea()
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
                                notificationManager.markAllRead()
                            }
                        }) {
                            Label("Mark All as Read", systemImage: "checkmark.circle")
                        }
                        
                        Button(role: .destructive, action: {
                            withAnimation {
                                notificationManager.clearRead()
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
    
    private func handleTap(id: UUID) {
        markAsRead(id: id)
        guard let notification = notifications.first(where: { $0.id == id }) else { return }
        // A new-product or price-change notification opens that product.
        if let link = notification.productLink {
            selectedProductLink = link
        } else if notification.type == .product || notification.type == .price {
            // Older notification from before the product link was stored:
            // find the product by name in the live catalogue.
            resolveProduct(from: notification)
        }
    }

    /// The product name is after the ": " in titles like
    /// "New product: Sambar Mix" or "Price change: Sambar Mix".
    private func productName(from notification: AppNotification) -> String {
        notification.title.components(separatedBy: ": ").last ?? notification.title
    }

    private func resolveProduct(from notification: AppNotification) {
        let name = productName(from: notification)
        let city = LocationState.shared.cityName
        guard !city.isEmpty, city != "Locating...", city != "Location Off" else { return }
        isResolvingProduct = true
        Task {
            let searchViewModel = SearchViewModel()
            await searchViewModel.loadAll(city: city)
            let match = searchViewModel.allItems.first {
                $0.product.name.localizedCaseInsensitiveCompare(name) == .orderedSame
            }
            await MainActor.run {
                isResolvingProduct = false
                if let match = match {
                    selectedProductLink = ProductLink(
                        product: match.product,
                        store: match.store,
                        categoryName: match.categoryName
                    )
                }
            }
        }
    }

    private func markAsRead(id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            notificationManager.markAsRead(id: id)
        }
    }

    private func deleteNotification(id: UUID) {
        withAnimation(.easeInOut(duration: 0.3)) {
            notificationManager.delete(id: id)
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
