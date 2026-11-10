//
//  ActiveOrdersSection.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-05-19.
//

import SwiftUI
import Combine

// MARK: - View Model

@MainActor
final class ActiveOrdersViewModel: ObservableObject {
    @Published var orders: [ActiveOrder] = []
    @Published var isLoading = false

    private let repo = OrderRepository.shared

    func fetch() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            orders = try await repo.fetchActiveOrders()
            // Order status changes (placed, processing, in transit,
            // delivered, cancelled) show as notifications.
            NotificationManager.shared.checkOrders(orders.map {
                (id: $0.id, trackingId: $0.trackingId, stage: $0.status.orderStage)
            })
        } catch {
            orders = []
        }
    }
}

// MARK: - Section Container

struct ActiveOrdersSection: View {
    @StateObject private var vm = ActiveOrdersViewModel()
    @State private var refreshRotation: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if vm.isLoading || !vm.orders.isEmpty {
                // Section header
                HStack(spacing: 0) {
                    HStack(spacing: 8) {
                        PulsingDot(color: .grocartGreen, size: 9)
                        Text("Active Orders")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.grocartPrimary)
                    }
                    Spacer()
                    Button {
                        withAnimation(.linear(duration: 0.6)) {
                            refreshRotation += 360
                        }
                        Task { await vm.fetch() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.grocartGreen)
                            .rotationEffect(.degrees(refreshRotation))
                            .frame(width: 36, height: 36)
                            .background(Color.grocartGreen.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)

                if vm.isLoading && vm.orders.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(0..<2, id: \.self) { _ in
                                OrderCardSkeleton()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(vm.orders) { order in
                                ActiveOrderCard(order: order)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .task { await vm.fetch() }
    }
}

// MARK: - Active Order Card

struct ActiveOrderCard: View {
    let order: ActiveOrder
    @State private var pulse = false

    private var deliverySteps: [String] { ["Confirmed", "Processing", "Assigned", "En Route"] }
    private var pickupSteps: [String]   { ["Confirmed", "Processing", "Ready"] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Top accent bar + type pill
            topBar

            VStack(alignment: .leading, spacing: 12) {
                // ── Progress steps
                progressSteps
                    .padding(.top, 14)

                // ── Status row
                statusRow

                Divider().opacity(0.5)

                // ── Store info
                storeRow

                // ── Items & total
                itemsRow

                // ── Schedule (date + time slot)
                if let schedule = order.scheduleDisplay {
                    scheduleRow(schedule)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 300)
        .background(Color.grocartSecondaryBackground.opacity(0.85))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(order.status.color.opacity(0.2), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack(alignment: .leading) {
            // Gradient accent
            LinearGradient(
                colors: [order.status.color, order.status.color.opacity(0.6)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 48)
            .cornerRadius(20, corners: [.topLeft, .topRight])

            HStack {
                // Order type pill
                HStack(spacing: 5) {
                    Image(systemName: order.isPickup ? "storefront.fill" : "bicycle")
                        .font(.system(size: 11, weight: .semibold))
                    Text(order.isPickup ? "Pickup" : "Delivery")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(order.status.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.95))
                .cornerRadius(20)

                Spacer()

                // Tracking ID
                Text(order.trackingId)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
        }
    }

    // MARK: - Progress Steps

    private var progressSteps: some View {
        let steps = order.isPickup ? pickupSteps : deliverySteps
        let currentStep = order.status.progressStep(isPickup: order.isPickup)
        let isCancelled = order.status == .cancelled

        return HStack(spacing: 0) {
            ForEach(steps.indices, id: \.self) { idx in
                let filled = !isCancelled && idx <= currentStep
                let isActive = !isCancelled && idx == currentStep

                // Step dot
                ZStack {
                    Circle()
                        .fill(filled ? order.status.color : Color.gray.opacity(0.2))
                        .frame(width: isActive ? 12 : 9, height: isActive ? 12 : 9)
                    if isActive && !isCancelled {
                        Circle()
                            .stroke(order.status.color.opacity(0.3), lineWidth: 4)
                            .frame(width: 20, height: 20)
                            .scaleEffect(pulse ? 1.3 : 1.0)
                            .opacity(pulse ? 0.0 : 0.8)
                    }
                }
                .frame(width: 22, height: 22)

                // Connector line (not after last step)
                if idx < steps.count - 1 {
                    Rectangle()
                        .fill(
                            filled && idx < currentStep
                                ? order.status.color
                                : Color.gray.opacity(0.2)
                        )
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Status Row

    private var statusRow: some View {
        HStack(spacing: 8) {
            Image(systemName: order.status.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(order.status.color)
                .frame(width: 28, height: 28)
                .background(order.status.color.opacity(0.1))
                .clipShape(Circle())

            Text(order.statusDisplay)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.grocartPrimary)

            Spacer()

            // Pulsing live indicator for non-cancelled
            if order.status != .cancelled {
                HStack(spacing: 4) {
                    Circle()
                        .fill(order.status.color)
                        .frame(width: 6, height: 6)
                        .scaleEffect(pulse ? 1.4 : 1.0)
                    Text("Live")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(order.status.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(order.status.color.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }

    // MARK: - Store Row

    private var storeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "storefront")
                .font(.system(size: 12))
                .foregroundColor(.grocartSecondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(order.storeName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.grocartPrimary)
                Text(order.storeAddress)
                    .font(.system(size: 11))
                    .foregroundColor(.grocartSecondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Items & Total Row

    private var itemsRow: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.grocartSecondary)
                Text("\(order.items.count) \(order.items.count == 1 ? "item" : "items")")
                    .font(.system(size: 12))
                    .foregroundColor(.grocartSecondary)
            }
            Spacer()
            Text(order.formattedTotal)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.grocartGreen)
        }
    }

    // MARK: - Schedule Row

    private func scheduleRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: order.isPickup ? "clock.fill" : "calendar")
                .font(.system(size: 11))
                .foregroundColor(.grocartSecondary)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.grocartSecondary)
                .lineLimit(1)
        }
    }

}

// MARK: - Skeleton Placeholder

private struct OrderCardSkeleton: View {
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 48)
                .cornerRadius(20, corners: [.topLeft, .topRight])

            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 14)
                        .frame(maxWidth: i % 2 == 0 ? .infinity : 160)
                }
            }
            .padding(16)
        }
        .frame(width: 300, height: 200)
        .background(Color.grocartSecondaryBackground.opacity(0.85))
        .cornerRadius(20)
        .opacity(shimmer ? 0.5 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

// MARK: - Pulsing Dot

struct PulsingDot: View {
    let color: Color
    let size: CGFloat
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(pulse ? 1.5 : 1.0)
                .opacity(pulse ? 0.0 : 1.0)
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - Corner Radius Helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

