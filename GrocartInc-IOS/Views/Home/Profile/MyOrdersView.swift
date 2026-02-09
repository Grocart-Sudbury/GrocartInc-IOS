//
//  MyOrdersView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

//
//  MyOrdersView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

// MARK: - Order Model
struct Order: Identifiable {
    let id = UUID()
    let orderNumber: String
    let date: String
    let items: [OrderItem]
    let totalAmount: String
    let status: OrderStatus
    let deliveryTime: String?
    
    var itemCount: Int { items.count }
}

struct OrderItem: Identifiable {
    let id = UUID()
    let name: String
    let quantity: Int
    let price: String
    let icon: String
}

enum OrderStatus: String {
    case delivered = "Delivered"
    case inTransit = "In Transit"
    case processing = "Processing"
    case cancelled = "Cancelled"
    
    var color: Color {
        switch self {
        case .delivered: return Color(red: 0.18, green: 0.72, blue: 0.47)
        case .inTransit: return Color(red: 0.25, green: 0.55, blue: 0.95)
        case .processing: return .orange
        case .cancelled: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .delivered: return "checkmark.circle.fill"
        case .inTransit: return "truck.box.fill"
        case .processing: return "clock.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

// MARK: - My Orders View
struct MyOrdersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: OrderStatus? = nil
    
    private let orders: [Order] = [
        Order(
            orderNumber: "GC-2026-0847",
            date: "Feb 7, 2026",
            items: [
                OrderItem(name: "Organic Bananas", quantity: 2, price: "$3.98", icon: "🍌"),
                OrderItem(name: "Whole Milk 2L", quantity: 1, price: "$5.49", icon: "🥛"),
                OrderItem(name: "Sourdough Bread", quantity: 1, price: "$4.99", icon: "🍞")
            ],
            totalAmount: "$18.46",
            status: .inTransit,
            deliveryTime: "Today, 2:00 - 3:00 PM"
        ),
        Order(
            orderNumber: "GC-2026-0832",
            date: "Feb 5, 2026",
            items: [
                OrderItem(name: "Chicken Breast 1kg", quantity: 1, price: "$12.99", icon: "🍗"),
                OrderItem(name: "Brown Rice 2kg", quantity: 1, price: "$6.49", icon: "🍚"),
                OrderItem(name: "Broccoli", quantity: 3, price: "$5.97", icon: "🥦"),
                OrderItem(name: "Greek Yogurt", quantity: 2, price: "$7.98", icon: "🥣")
            ],
            totalAmount: "$37.43",
            status: .delivered,
            deliveryTime: nil
        ),
        Order(
            orderNumber: "GC-2026-0815",
            date: "Feb 1, 2026",
            items: [
                OrderItem(name: "Atlantic Salmon", quantity: 1, price: "$14.99", icon: "🐟"),
                OrderItem(name: "Avocados", quantity: 4, price: "$7.96", icon: "🥑")
            ],
            totalAmount: "$26.95",
            status: .delivered,
            deliveryTime: nil
        ),
        Order(
            orderNumber: "GC-2026-0798",
            date: "Jan 28, 2026",
            items: [
                OrderItem(name: "Pasta Sauce", quantity: 2, price: "$8.98", icon: "🍝"),
                OrderItem(name: "Spaghetti 500g", quantity: 2, price: "$5.98", icon: "🍝"),
                OrderItem(name: "Parmesan Cheese", quantity: 1, price: "$8.99", icon: "🧀")
            ],
            totalAmount: "$27.95",
            status: .cancelled,
            deliveryTime: nil
        )
    ]
    
    private var filteredOrders: [Order] {
        if let filter = selectedFilter {
            return orders.filter { $0.status == filter }
        }
        return orders
    }
    
    private let filters: [(String, OrderStatus?)] = [
        ("All", nil),
        ("In Transit", .inTransit),
        ("Delivered", .delivered),
        ("Cancelled", .cancelled)
    ]
    
    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(filters, id: \.0) { label, status in
                            FilterChip(
                                label: label,
                                isSelected: selectedFilter == status,
                                color: status?.color ?? .grocartGreen
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedFilter = status
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                
                if filteredOrders.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bag")
                            .font(.system(size: 44))
                            .foregroundColor(.grocartSecondary.opacity(0.4))
                        Text("No orders found")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.grocartSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            ForEach(filteredOrders) { order in
                                OrderCard(order: order)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .navigationTitle("My Orders")
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
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : .grocartSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? color : Color.grocartSecondaryBackground)
                )
        }
    }
}

// MARK: - Order Card
struct OrderCard: View {
    let order: Order
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(order.status.color.opacity(0.1))
                        .frame(width: 42, height: 42)
                    
                    Image(systemName: order.status.icon)
                        .font(.system(size: 18))
                        .foregroundColor(order.status.color)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(order.orderNumber)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.grocartPrimary)
                    
                    Text(order.date)
                        .font(.system(size: 12))
                        .foregroundColor(.grocartSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 3) {
                    Text(order.totalAmount)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.grocartPrimary)
                    
                    Text(order.status.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(order.status.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(order.status.color.opacity(0.1))
                        )
                }
            }
            .padding(16)
            
            // Delivery Time Banner (for in-transit orders)
            if let deliveryTime = order.deliveryTime {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                    Text(deliveryTime)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(order.status.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(order.status.color.opacity(0.06))
            }
            
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 1)
            
            // Items Preview
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                VStack(spacing: 0) {
                    if isExpanded {
                        ForEach(order.items) { item in
                            HStack(spacing: 10) {
                                Text(item.icon)
                                    .font(.system(size: 20))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.grocartPrimary)
                                    Text("Qty: \(item.quantity)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.grocartSecondary)
                                }
                                
                                Spacer()
                                
                                Text(item.price)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.grocartPrimary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                    } else {
                        HStack(spacing: 6) {
                            HStack(spacing: -4) {
                                ForEach(Array(order.items.prefix(3).enumerated()), id: \.offset) { _, item in
                                    Text(item.icon)
                                        .font(.system(size: 16))
                                        .frame(width: 28, height: 28)
                                        .background(Color.grocartBackground)
                                        .clipShape(Circle())
                                }
                            }
                            
                            Text("\(order.itemCount) item\(order.itemCount > 1 ? "s" : "")")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.grocartSecondary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.grocartSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    
                    if isExpanded {
                        HStack {
                            Spacer()
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.grocartSecondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            
            // Reorder Button (for delivered orders)
            if order.status == .delivered {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 1)
                
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Reorder")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.grocartGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color.grocartSecondaryBackground)
        .cornerRadius(16)
    }
}

#Preview {
    NavigationStack {
        MyOrdersView()
    }
}
