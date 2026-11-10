//
//  SubscriptionReviewView.swift
//  GrocartInc-IOS
//
//  Step 2 of a new subscription: verify everything before committing.
//  Shows the store, the chosen items (quantities can still be adjusted),
//  how often, delivery or pickup, the address, the billing card and
//  the total per delivery. Start subscription creates it; the
//  confirmation then replaces this page.
//

import SwiftUI

struct SubscriptionReviewView: View {
    let store: Store
    @ObservedObject var createVM: SubscriptionCreateViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()

            if createVM.createdSubscription != nil {
                confirmationView
            } else {
                reviewForm
            }
        }
        .navigationTitle("Review subscription")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Review form
    private var reviewForm: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Store
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    Text(store.displayAddress)
                        .font(.system(size: 13))
                        .foregroundColor(.black.opacity(0.6))
                }

                // Items
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your items")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                    if createVM.selectedItems.isEmpty {
                        Text("No items selected — go back to add items.")
                            .font(.system(size: 13))
                            .foregroundColor(.black.opacity(0.6))
                    } else {
                        ForEach(createVM.selectedItems) { item in
                            reviewItemRow(item)
                        }
                    }
                }

                // How often?
                VStack(alignment: .leading, spacing: 8) {
                    Text("How often?")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                    Picker("Frequency", selection: $createVM.frequency) {
                        ForEach(SubscriptionFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("First delivery \(createVM.formattedFirstDelivery).")
                        .font(.system(size: 13))
                        .foregroundColor(.black.opacity(0.6))
                }

                // Delivery or pickup?
                VStack(alignment: .leading, spacing: 8) {
                    Text("Delivery or pickup?")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                    Picker("Fulfilment", selection: $createVM.fulfilment) {
                        ForEach(OrderType.allCases, id: \.self) { type in
                            Text(type.display).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    if createVM.fulfilment == .delivery {
                        addressMenu
                    } else {
                        Text("Pick up your items at \(store.name) on each delivery day.")
                            .font(.system(size: 13))
                            .foregroundColor(.black.opacity(0.6))
                    }
                }

                // Billed to
                VStack(alignment: .leading, spacing: 8) {
                    Text("Billed to")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                    cardMenu
                    Text("Your saved card is charged automatically on each \(createVM.frequency.displayName.lowercased()) delivery.")
                        .font(.system(size: 13))
                        .foregroundColor(.black.opacity(0.6))
                }

                // Total
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Total per delivery")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                        Spacer()
                        Text(createVM.formattedTotalPerCycle)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                    }
                    Text("Delivery fee and taxes are added by the store at each delivery.")
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.6))
                }

                if let reason = createVM.createBlockedReason {
                    Text(reason)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.orange)
                }

                // Commit
                Button {
                    Task { await createVM.create() }
                } label: {
                    if createVM.isCreating {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    } else {
                        Text("Start subscription")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .background(Color.black)
                .cornerRadius(18)
                .disabled(!createVM.canCreate)
                .opacity(createVM.canCreate ? 1 : 0.5)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Item row (with a stepper to adjust the quantity)
    private func reviewItemRow(_ item: SubscriptionItem) -> some View {
        HStack(spacing: 12) {
            CachedAsyncImage(urlString: item.imageUrl ?? "") { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipped()
                        .cornerRadius(10)
                default:
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.grocartSecondaryBackground)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "basket.fill")
                                .foregroundColor(.black.opacity(0.2))
                        )
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.productName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                Text("\(String(format: "$%.2f", item.unitPrice)) each")
                    .font(.system(size: 12))
                    .foregroundColor(.black.opacity(0.6))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(String(format: "$%.2f", item.lineTotal))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                HStack(spacing: 0) {
                    Button {
                        createVM.setQuantity(item.quantity - 1, for: item.productId)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 26, height: 26)
                    }
                    Text("\(item.quantity)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(minWidth: 20)
                    Button {
                        createVM.setQuantity(item.quantity + 1, for: item.productId)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Color.black)
                            .clipShape(Circle())
                    }
                }
                .padding(3)
                .glassPill(tint: .clear)
            }
        }
        .padding(10)
        .glassCard(cornerRadius: 16, tint: .clear)
    }

    // MARK: - Address menu (delivery)
    private var addressMenu: some View {
        Group {
            if createVM.isLoadingAddresses {
                ProgressView()
                    .padding(.vertical, 8)
            } else if createVM.addresses.isEmpty {
                Text("No delivery address saved yet. Add one in Profile → Delivery Addresses, then come back.")
                    .font(.system(size: 13))
                    .foregroundColor(.black.opacity(0.6))
            } else {
                Menu {
                    ForEach(createVM.addresses) { address in
                        Button {
                            createVM.selectedAddressId = address.id
                        } label: {
                            Label(address.label, systemImage: createVM.selectedAddressId == address.id ? "checkmark" : "mappin.circle")
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.black)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(createVM.selectedAddress?.label ?? "Choose address")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                            Text(createVM.selectedAddress?.displayAddress ?? "")
                                .font(.system(size: 12))
                                .foregroundColor(.black.opacity(0.6))
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.black.opacity(0.5))
                    }
                    .padding(12)
                    .glassCard(cornerRadius: 14, tint: .clear)
                }
            }
        }
    }

    // MARK: - Card menu (billing)
    private var cardMenu: some View {
        Group {
            if createVM.isLoadingCards {
                ProgressView()
                    .padding(.vertical, 8)
            } else if createVM.savedCards.isEmpty {
                Text("No saved card yet. Add one in Profile → Payment Methods, then come back to finish this subscription.")
                    .font(.system(size: 13))
                    .foregroundColor(.black.opacity(0.6))
            } else {
                Menu {
                    ForEach(createVM.savedCards) { card in
                        Button {
                            createVM.selectedCardId = card.id
                        } label: {
                            Label("\(card.displayBrand) •• \(card.last4)", systemImage: createVM.selectedCardId == card.id ? "checkmark" : "creditcard")
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(.black)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(createVM.selectedCard.map { "\($0.displayBrand) •• \($0.last4)" } ?? "Choose a card")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                            Text(createVM.selectedCard.map { "Expires \($0.formattedExpiry)" } ?? "")
                                .font(.system(size: 12))
                                .foregroundColor(.black.opacity(0.6))
                        }
                        Spacer()
                        if createVM.selectedCard?.isDefault == true {
                            Text("Default")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.grocartGreen)
                                .cornerRadius(10)
                        }
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.black.opacity(0.5))
                    }
                    .padding(12)
                    .glassCard(cornerRadius: 14, tint: .clear)
                }
            }
        }
    }

    // MARK: - Confirmation
    private var confirmationView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.grocartGreen.opacity(0.15))
                    .frame(width: 88, height: 88)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.grocartGreen)
            }
            Text("Subscription started")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
            if let sub = createVM.createdSubscription {
                Text("\(sub.storeName) · \(sub.frequency.displayName) · \(sub.fulfilment.display)\n\(sub.formattedTotalPerCycle) per delivery · first delivery \(sub.formattedNextDelivery)")
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.7))
                    .multilineTextAlignment(.center)
                if sub.isLocalOnly {
                    Text("Saved on this device — the backend did not confirm it yet, so it is not billed. It will work here, and you can recreate it once the backend enables subscriptions.")
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                } else {
                    Text("Your saved card will be charged automatically on each delivery.")
                        .font(.system(size: 13))
                        .foregroundColor(.black.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
            }
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .cornerRadius(18)
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
    }
}
