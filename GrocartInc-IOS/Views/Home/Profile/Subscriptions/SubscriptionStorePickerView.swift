//
//  SubscriptionStorePickerView.swift
//  GrocartInc-IOS
//
//  Step 1 of a new subscription: choose the store to subscribe from.
//

import SwiftUI

struct SubscriptionStorePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var createVM = SubscriptionCreateViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.grocartBackground.ignoresSafeArea()

                if createVM.isLoadingStores && createVM.stores.isEmpty {
                    ProgressView()
                } else if createVM.stores.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "storefront")
                            .font(.system(size: 32))
                            .foregroundColor(.black.opacity(0.3))
                        Text("No stores available right now")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                        Text("Try again in a moment.")
                            .font(.system(size: 13))
                            .foregroundColor(.black.opacity(0.6))
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose a store")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                            Text("You will subscribe to items from this store. You can change the store later by starting a new subscription.")
                                .font(.system(size: 13))
                                .foregroundColor(.black.opacity(0.6))
                                .padding(.horizontal, 20)

                            ForEach(createVM.stores) { store in
                                NavigationLink(destination: SubscriptionCreateView(store: store, createVM: createVM)) {
                                    storeRow(store)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("New subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.black)
                }
            }
            .task { await createVM.loadStores() }
        }
    }

    private func storeRow(_ store: Store) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.grocartGreen.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: "storefront.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.grocartGreen)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(store.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                Text(store.displayAddress)
                    .font(.system(size: 12))
                    .foregroundColor(.black.opacity(0.6))
                    .lineLimit(1)
                Text(store.formattedDeliveryFee)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black.opacity(0.6))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.black.opacity(0.4))
        }
        .padding(14)
        .glassCard(cornerRadius: 16, tint: .clear)
        .padding(.horizontal, 20)
    }
}
