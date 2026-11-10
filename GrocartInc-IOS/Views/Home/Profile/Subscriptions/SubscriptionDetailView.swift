//
//  SubscriptionDetailView.swift
//  GrocartInc-IOS
//
//  One subscription: its items, schedule, fulfilment, billing card,
//  and next delivery. Cancel removes it.
//

import SwiftUI

struct SubscriptionDetailView: View {
    let subscription: Subscription
    let onCancelled: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SubscriptionViewModel()
    @State private var showCancelAlert = false
    @State private var isCancelling = false

    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if subscription.isLocalOnly {
                        localOnlyNote
                    }

                    scheduleSection
                    itemsSection
                    billingSection

                    if subscription.status == .active {
                        Button {
                            showCancelAlert = true
                        } label: {
                            if isCancelling {
                                ProgressView()
                                    .tint(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            } else {
                                Text("Cancel subscription")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                        }
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(18)
                        .disabled(isCancelling)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Cancel this subscription?", isPresented: $showCancelAlert) {
            Button("Keep it", role: .cancel) {}
            Button("Cancel subscription", role: .destructive) {
                Task { await cancel() }
            }
        } message: {
            Text("You will not be billed again for \(subscription.storeName). This cannot be undone.")
        }
        .alert("Something went wrong", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.grocartGreen.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: "repeat.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.grocartGreen)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(subscription.storeName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                    Text(subscription.status.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(subscription.status == .active ? .grocartGreen : .black.opacity(0.6))
                }
                Spacer()
            }
            Text("\(subscription.formattedTotalPerCycle) per delivery · \(subscription.itemCount) items")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.black)
        }
    }

    private var localOnlyNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "iphone")
                .foregroundColor(.orange)
            Text("Saved on this device — the backend did not confirm this subscription, so it is not billed. Recreate it once the backend enables subscriptions.")
                .font(.system(size: 13))
                .foregroundColor(.orange)
        }
        .padding(14)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(14)
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Schedule")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
            detailRow(label: "Frequency", value: subscription.frequency.displayName)
            detailRow(label: "Fulfilment", value: subscription.fulfilment.display)
            if subscription.fulfilment == .delivery, let address = subscription.deliveryAddressLabel {
                detailRow(label: "Deliver to", value: address)
            } else if subscription.fulfilment == .pickup {
                detailRow(label: "Pickup at", value: subscription.storeName)
            }
            detailRow(label: "Next delivery", value: subscription.formattedNextDelivery)
        }
        .padding(16)
        .glassCard(cornerRadius: 16, tint: .clear)
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Items (\(subscription.items.count))")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
            ForEach(subscription.items) { item in
                HStack(spacing: 10) {
                    CachedAsyncImage(urlString: item.imageUrl ?? "") { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipped()
                                .cornerRadius(10)
                        default:
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.grocartSecondaryBackground)
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Image(systemName: "basket.fill")
                                        .foregroundColor(.black.opacity(0.2))
                                )
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.productName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .lineLimit(2)
                        Text("\(item.formattedUnitPrice) × \(item.quantity)")
                            .font(.system(size: 12))
                            .foregroundColor(.black.opacity(0.6))
                    }
                    Spacer()
                    Text(item.formattedLineTotal)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16, tint: .clear)
    }

    private var billingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Billing")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
            detailRow(label: "Card", value: subscription.paymentCardLabel ?? "Saved card")
            Text("Charged automatically on each \(subscription.frequency.displayName.lowercased()) delivery.")
                .font(.system(size: 13))
                .foregroundColor(.black.opacity(0.6))
        }
        .padding(16)
        .glassCard(cornerRadius: 16, tint: .clear)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.black.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.black)
                .multilineTextAlignment(.trailing)
        }
    }

    private func cancel() async {
        isCancelling = true
        await viewModel.cancel(subscription)
        isCancelling = false
        if viewModel.errorMessage == nil {
            onCancelled()
            dismiss()
        }
    }
}
