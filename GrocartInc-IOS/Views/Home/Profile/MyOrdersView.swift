// MyOrdersView.swift
// GrocartInc-IOS

import SwiftUI

// MARK: - My Orders View

struct MyOrdersView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = OrdersViewModel()
    @State private var selectedStatus: CustomerOrderStatus? = nil

    private let filters: [(String, CustomerOrderStatus?)] = [
        ("All", nil),
        ("In Transit", .inTransit),
        ("Delivered", .delivered),
        ("Processing", .processing),
        ("Cancelled", .cancelled)
    ]

    private var filteredOrders: [CustomerOrderSummary] {
        guard let status = selectedStatus else { return viewModel.orders }
        return viewModel.orders.filter { $0.status == status }
    }

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
                                isSelected: selectedStatus == status,
                                color: status?.color ?? .grocartGreen
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedStatus = status
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 44))
                            .foregroundColor(.grocartSecondary.opacity(0.4))
                        Text(error)
                            .font(.system(size: 15))
                            .foregroundColor(.grocartSecondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") { viewModel.load() }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.grocartGreen)
                    }
                    .padding(.horizontal, 40)
                    Spacer()
                } else if filteredOrders.isEmpty {
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
        .onAppear { viewModel.load() }
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
    let order: CustomerOrderSummary
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
                    Text(order.trackingId ?? "#\(order.id)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.grocartPrimary)
                    Text(order.formattedDate)
                        .font(.system(size: 12))
                        .foregroundColor(.grocartSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(order.formattedTotal)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.grocartPrimary)
                    Text(order.status.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(order.status.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(order.status.color.opacity(0.1)))
                }
            }
            .padding(16)

            // Delivery banner
            if let delivery = order.deliveryDisplay {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill").font(.system(size: 12))
                    Text(delivery).font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(order.status.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(order.status.color.opacity(0.06))
            }

            Rectangle().fill(Color.gray.opacity(0.1)).frame(height: 1)

            // Items section
            if let items = order.items, !items.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    VStack(spacing: 0) {
                        if isExpanded {
                            ForEach(items) { item in
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.productName)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.grocartPrimary)
                                        Text("Qty: \(item.quantity)")
                                            .font(.system(size: 11))
                                            .foregroundColor(.grocartSecondary)
                                    }
                                    Spacer()
                                    Text(item.formattedPrice)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.grocartPrimary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                            HStack {
                                Spacer()
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.grocartSecondary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        } else {
                            HStack(spacing: 6) {
                                Text("\(order.itemCount) item\(order.itemCount == 1 ? "" : "s")")
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
                    }
                }
            } else if order.itemCount == 0 {
                HStack {
                    Text("No item details available")
                        .font(.system(size: 12))
                        .foregroundColor(.grocartSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color.grocartSecondaryBackground)
        .cornerRadius(16)
    }
}

#Preview {
    NavigationStack { MyOrdersView() }
}
