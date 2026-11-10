//
//  PaymentMethodsView.swift
//  GrocartInc-IOS
//
//  Real saved cards from the backend (GET /payment/cards). Cards are
//  added through Stripe (setup intent + attach) and removed with
//  DELETE /payment/cards/{id}. There is no demo data here — an empty
//  list means the account has no saved cards yet.
//

import SwiftUI

// MARK: - Payment Methods View
struct PaymentMethodsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cards: [SavedCard] = []
    @State private var selectedCardIndex = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showAddCard = false
    @State private var cardToDelete: SavedCard?
    @State private var isDeleting = false

    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else if let error = errorMessage {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.orange)
                            Text("Couldn't load your cards")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.black.opacity(0.6))
                                .multilineTextAlignment(.center)
                            Button("Try again") {
                                Task { await loadCards() }
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            .cornerRadius(12)
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 40)
                    } else if cards.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "creditcard")
                                .font(.system(size: 36))
                                .foregroundColor(.black.opacity(0.3))
                            Text("No saved cards yet")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                            Text("Add a card to pay faster at checkout and to use it for subscriptions.")
                                .font(.system(size: 13))
                                .foregroundColor(.black.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 40)
                    } else {
                        // Card Carousel
                        TabView(selection: $selectedCardIndex) {
                            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                                SavedCardView(card: card)
                                    .padding(.horizontal, 20)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .always))
                        .frame(height: 220)

                        // Card Actions
                        HStack(spacing: 12) {
                            CardActionButton(
                                icon: "trash.circle.fill",
                                label: "Remove",
                                color: .red,
                                isActive: false
                            ) {
                                cardToDelete = cards[selectedCardIndex]
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Add Card
                    Button {
                        showAddCard = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.grocartGreen.opacity(0.1))
                                    .frame(width: 42, height: 42)

                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.grocartGreen)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Add New Card")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.grocartPrimary)

                                Text("Visa, Mastercard, or Amex")
                                    .font(.system(size: 12))
                                    .foregroundColor(.grocartSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.grocartSecondary)
                        }
                        .padding(16)
                        .background(Color.grocartSecondaryBackground)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)

                    // Security Note
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.grocartGreen)

                        Text("Your payment information is encrypted and securely stored. We never share your card details.")
                            .font(.system(size: 12))
                            .foregroundColor(.grocartSecondary)
                            .lineSpacing(2)
                    }
                    .padding(16)
                    .background(Color.grocartGreen.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
                .padding(.top, 10)
            }
        }
        .navigationTitle("Payment Methods")
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
        .task {
            await loadCards()
        }
        .sheet(isPresented: $showAddCard) {
            StandaloneAddCardView(setAsDefault: cards.isEmpty) { _ in
                Task { await loadCards() }
            }
        }
        .alert("Remove this card?", isPresented: .constant(cardToDelete != nil)) {
            Button("Cancel", role: .cancel) { cardToDelete = nil }
            Button("Remove", role: .destructive) {
                if let card = cardToDelete {
                    cardToDelete = nil
                    Task { await deleteCard(card) }
                }
            }
        } message: {
            if let card = cardToDelete {
                Text("\(card.displayBrand) •• \(card.last4) will be removed from your account.")
            }
        }
    }

    // MARK: - Load / delete
    private func loadCards() async {
        isLoading = true
        errorMessage = nil
        do {
            cards = try await PaymentRepository.shared.getSavedCards()
            if selectedCardIndex >= cards.count {
                selectedCardIndex = max(0, cards.count - 1)
            }
        } catch {
            cards = []
            errorMessage = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    private func deleteCard(_ card: SavedCard) async {
        isDeleting = true
        do {
            try await PaymentRepository.shared.deleteCard(card.id)
            await loadCards()
        } catch {
            errorMessage = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
        }
        isDeleting = false
    }
}

// MARK: - Saved Card Visual
struct SavedCardView: View {
    let card: SavedCard

    private var gradientColors: [Color] {
        switch card.brand.lowercased() {
        case "visa":
            return [Color(red: 0.12, green: 0.14, blue: 0.22), Color(red: 0.22, green: 0.26, blue: 0.38)]
        case "mastercard":
            return [Color(red: 0.18, green: 0.42, blue: 0.72), Color(red: 0.25, green: 0.55, blue: 0.90)]
        case "amex", "american express":
            return [Color(red: 0.05, green: 0.35, blue: 0.35), Color(red: 0.10, green: 0.55, blue: 0.55)]
        default:
            return [Color(red: 0.12, green: 0.14, blue: 0.22), Color(red: 0.22, green: 0.26, blue: 0.38)]
        }
    }

    private var holderName: String {
        if let user = SessionManager.shared.currentUser {
            let name = "\(user.firstName) \(user.lastName)".trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { return name.uppercased() }
        }
        return "CARD HOLDER"
    }

    var body: some View {
        ZStack {
            // Card Background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Subtle pattern
            GeometryReader { geo in
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 200)
                    .offset(x: geo.size.width * 0.5, y: -40)

                Circle()
                    .fill(Color.white.opacity(0.03))
                    .frame(width: 160)
                    .offset(x: -40, y: geo.size.height * 0.6)
            }
            .clipped()
            .cornerRadius(20)

            VStack(alignment: .leading, spacing: 0) {
                // Top: Chip + Default
                HStack {
                    // Chip
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.85, green: 0.75, blue: 0.50), Color(red: 0.75, green: 0.65, blue: 0.40)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 28)
                        .overlay(
                            VStack(spacing: 3) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Rectangle()
                                        .fill(Color.white.opacity(0.3))
                                        .frame(height: 0.5)
                                }
                            }
                            .padding(.horizontal, 4)
                        )

                    Spacer()

                    if card.isDefault {
                        Text("DEFAULT")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.15)))
                    }
                }

                Spacer()

                // Card Number
                HStack(spacing: 14) {
                    ForEach(0..<3, id: \.self) { _ in
                        Text("••••")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Text(card.last4)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                // Bottom: Name + Expiry + Brand
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CARD HOLDER")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        Text(holderName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("EXPIRES")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        Text(card.formattedExpiry)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Text(card.displayBrand.uppercased())
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.leading, 12)
                }
            }
            .padding(24)
        }
        .frame(height: 195)
        .shadow(color: gradientColors.first?.opacity(0.3) ?? Color.clear, radius: 15, y: 8)
    }
}

// MARK: - Card Action Button
struct CardActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isActive ? color : .grocartSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                (isActive ? color.opacity(0.08) : Color.grocartSecondaryBackground)
            )
            .cornerRadius(14)
        }
    }
}

#Preview {
    NavigationStack {
        PaymentMethodsView()
    }
}
