//
//  OrderConfirmationView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-04-13.
//

import SwiftUI

struct OrderConfirmationView: View {
    let order: OrderResponse
    let pointsEarned: Int
    let scratchCard: ScratchCard?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var scratchCardManager = ScratchCardManager.shared
    @State private var showScratchCard = false

    init(order: OrderResponse, pointsEarned: Int = 0, scratchCard: ScratchCard? = nil) {
        self.order = order
        self.pointsEarned = pointsEarned
        self.scratchCard = scratchCard
    }

    /// The earned card as it stands now in the manager (so the row
    /// updates to the revealed prize after the user scratches it).
    private var liveScratchCard: ScratchCard? {
        guard let card = scratchCard else { return nil }
        return scratchCardManager.cards.first(where: { $0.id == card.id }) ?? card
    }

    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Success illustration
                    VStack(spacing: 20) {
                        Spacer().frame(height: 60)

                        ZStack {
                            Circle()
                                .fill(Color.grocartGreen.opacity(0.12))
                                .frame(width: 130, height: 130)
                            Circle()
                                .fill(Color.grocartGreen.opacity(0.2))
                                .frame(width: 100, height: 100)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.grocartGreen)
                        }

                        Text("Order Placed!")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.grocartPrimary)

                        Text(order.isPickup
                             ? "Your order is confirmed. We'll notify you when it's ready for pickup."
                             : "Your order has been received and is being prepared.")
                            .font(.system(size: 15))
                            .foregroundColor(.grocartSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 36)

                    // Tracking ID card
                    VStack(spacing: 6) {
                        Text("Tracking ID")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.grocartSecondary)
                        Text(order.trackingId)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.grocartGreen)
                            .tracking(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color.grocartGreen.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)

                    // Order details
                    VStack(spacing: 0) {
                        detailRow(icon: "person.fill",
                                  label: "Customer",
                                  value: "\(order.firstName) \(order.lastName)")
                        Divider().padding(.horizontal, 16)
                        if order.isPickup {
                            detailRow(icon: "storefront.fill",
                                      label: "Order type",
                                      value: "In-store Pickup")
                            if let date = order.preferredPickupDate {
                                Divider().padding(.horizontal, 16)
                                detailRow(icon: "calendar",
                                          label: "Pickup date",
                                          value: formatDate(date))
                            }
                            if !order.pickupSlotDisplay.isEmpty {
                                Divider().padding(.horizontal, 16)
                                detailRow(icon: "clock.fill",
                                          label: "Pickup time",
                                          value: order.pickupSlotDisplay)
                            }
                        } else {
                            if let address = order.address, let city = order.city {
                                detailRow(icon: "mappin.circle.fill",
                                          label: "Delivery to",
                                          value: "\(address), \(city)")
                                Divider().padding(.horizontal, 16)
                            }
                            if let date = order.preferredDeliveryDate {
                                detailRow(icon: "calendar",
                                          label: "Delivery date",
                                          value: formatDate(date))
                                Divider().padding(.horizontal, 16)
                            }
                            if !order.deliverySlotDisplay.isEmpty {
                                detailRow(icon: "clock.fill",
                                          label: "Time slot",
                                          value: order.deliverySlotDisplay)
                                Divider().padding(.horizontal, 16)
                            }
                        }
                        detailRow(icon: "creditcard.fill",
                                  label: "Payment",
                                  value: order.paymentMethodDisplay)
                        Divider().padding(.horizontal, 16)
                        detailRow(icon: "cart.fill",
                                  label: "Total charged",
                                  value: order.formattedTotal,
                                  valueColor: .grocartGreen)
                        Divider().padding(.horizontal, 16)
                        detailRow(icon: "star.fill",
                                  label: "Points earned",
                                  value: "+\(pointsEarned) pts",
                                  valueColor: .grocartGreen)
                    }
                    .background(Color.grocartSecondaryBackground.opacity(0.6))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)

                    // Scratch card earned from this order
                    if let card = liveScratchCard {
                        Button(action: { showScratchCard = true }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(
                                            LinearGradient(
                                                colors: card.gradientColors,
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 48, height: 48)
                                    Image(systemName: card.isScratched ? "checkmark" : "sparkles")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("You earned a scratch card!")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.grocartPrimary)
                                    Text(card.isScratched ? card.displayDiscount : "Tap to scratch & reveal your gift")
                                        .font(.system(size: 12))
                                        .foregroundColor(.grocartSecondary)
                                }
                                Spacer()
                                Image(systemName: "hand.draw.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.orange)
                            }
                            .padding(16)
                            .background(Color.grocartSecondaryBackground)
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }

                    // Status badge
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("Status: \(order.status.capitalized.replacingOccurrences(of: "_", with: " "))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.grocartPrimary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(20)
                    .padding(.bottom, 40)

                    // Done button
                    Button(action: {
                        dismiss()
                        NotificationCenter.default.post(name: .navigateToHome, object: nil)
                    }) {
                        Text("Back to Home")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.grocartGreen)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }

            if showScratchCard, let card = liveScratchCard {
                LocalScratchCardOverlay(
                    card: card,
                    onDismiss: { showScratchCard = false },
                    onScratched: { ScratchCardManager.shared.markScratched(card) }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }

    private func detailRow(icon: String, label: String, value: String,
                            valueColor: Color = .grocartPrimary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.grocartGreen)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.grocartSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(valueColor)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .frame(maxWidth: 180, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func formatDate(_ iso: String) -> String {
        let input = DateFormatter(); input.dateFormat = "yyyy-MM-dd"
        let output = DateFormatter(); output.dateFormat = "EEEE, MMM d"
        if let date = input.date(from: iso) { return output.string(from: date) }
        return iso
    }
}

// Make OrderResponse conform to Identifiable for fullScreenCover(item:)
extension OrderResponse: Identifiable {}

extension Notification.Name {
    static let navigateToHome = Notification.Name("com.grocartinc.navigateToHome")
    static let navigateToCart = Notification.Name("com.grocartinc.navigateToCart")
    static let dismissProductDetail = Notification.Name("com.grocartinc.dismissProductDetail")
}
