//
//  SubscriptionListView.swift
//  GrocartInc-IOS
//
//  My Subscriptions: the customer's recurring orders. Each one is billed
//  on its saved card every week, every 2 weeks, or every month.
//

import SwiftUI

struct SubscriptionListView: View {
    @StateObject private var viewModel = SubscriptionViewModel()
    @State private var showStorePicker = false

    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()

            if viewModel.isLoading && viewModel.subscriptions.isEmpty {
                ProgressView()
            } else if viewModel.subscriptions.isEmpty {
                emptyState
            } else {
                subscriptionList
            }
        }
        .navigationTitle("Subscriptions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showStorePicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(isPresented: $showStorePicker) {
            SubscriptionStorePickerView()
        }
        .alert("Something went wrong", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var subscriptionList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(viewModel.subscriptions) { subscription in
                    NavigationLink(destination: SubscriptionDetailView(subscription: subscription) {
                        Task { await viewModel.load() }
                    }) {
                        subscriptionRow(subscription)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showStorePicker = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("New subscription")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .cornerRadius(18)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }

    private func subscriptionRow(_ subscription: Subscription) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.grocartGreen.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "repeat.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.grocartGreen)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(subscription.storeName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    Text("\(subscription.frequency.displayName) · \(subscription.fulfilment.display)")
                        .font(.system(size: 13))
                        .foregroundColor(.black.opacity(0.6))
                }
                Spacer()
                Text(subscription.formattedTotalPerCycle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
            }

            HStack(spacing: 6) {
                Text("\(subscription.itemCount) items")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black.opacity(0.6))
                Text("·")
                    .foregroundColor(.black.opacity(0.4))
                if subscription.status == .cancelled {
                    Text("Delivery on \(subscription.formattedCancelledDelivery) cancelled")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.black.opacity(0.6))
                } else {
                    Text("Next delivery \(subscription.formattedNextDelivery)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.black.opacity(0.6))
                }
                Spacer()
                Text(subscription.status.displayName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(subscription.status == .active ? .white : .black.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(subscription.status == .active ? Color.grocartGreen : Color.black.opacity(0.08))
                    .cornerRadius(10)
            }

            if subscription.isLocalOnly {
                HStack(spacing: 6) {
                    Image(systemName: "iphone")
                        .font(.system(size: 11))
                    Text("Saved on this device — not billed yet. The backend has not confirmed this subscription.")
                        .font(.system(size: 11))
                }
                .foregroundColor(.orange)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16, tint: .clear)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.grocartGreen.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: "repeat.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.grocartGreen)
            }
            Text("No subscriptions yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)
            Text("Pick a store, choose the items you want again and again, and we will deliver or prepare them every week, every 2 weeks, or every month — billed automatically on your saved card.")
                .font(.system(size: 14))
                .foregroundColor(.black.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showStorePicker = true
            } label: {
                Text("Start a subscription")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .cornerRadius(18)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
    }
}
