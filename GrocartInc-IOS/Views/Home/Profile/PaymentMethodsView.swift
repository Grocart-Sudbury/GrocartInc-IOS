//
//  PaymentMethodsView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//


//
//  PaymentMethodsView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

// MARK: - Payment Card Model
struct PaymentCard: Identifiable {
    let id = UUID()
    let type: CardType
    let lastFour: String
    let holderName: String
    let expiryDate: String
    var isDefault: Bool
    let gradientColors: [Color]
}

enum CardType: String {
    case visa = "Visa"
    case mastercard = "Mastercard"
    case amex = "Amex"
    
    var icon: String {
        switch self {
        case .visa: return "creditcard.fill"
        case .mastercard: return "creditcard.fill"
        case .amex: return "creditcard.fill"
        }
    }
    
    var logo: String {
        switch self {
        case .visa: return "VISA"
        case .mastercard: return "MC"
        case .amex: return "AMEX"
        }
    }
}

// MARK: - Payment Methods View
struct PaymentMethodsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cards: [PaymentCard] = [
        PaymentCard(
            type: .visa,
            lastFour: "4291",
            holderName: "JOHN DOE",
            expiryDate: "09/28",
            isDefault: true,
            gradientColors: [Color(red: 0.12, green: 0.14, blue: 0.22), Color(red: 0.22, green: 0.26, blue: 0.38)]
        ),
        PaymentCard(
            type: .mastercard,
            lastFour: "8103",
            holderName: "JOHN DOE",
            expiryDate: "03/27",
            isDefault: false,
            gradientColors: [Color(red: 0.18, green: 0.42, blue: 0.72), Color(red: 0.25, green: 0.55, blue: 0.90)]
        )
    ]
    @State private var selectedCardIndex = 0
    
    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Card Carousel
                    TabView(selection: $selectedCardIndex) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            CreditCardView(card: card)
                                .padding(.horizontal, 20)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .frame(height: 220)
                    
                    // Card Actions
                    if !cards.isEmpty {
                        HStack(spacing: 12) {
                            CardActionButton(
                                icon: "checkmark.circle.fill",
                                label: cards[selectedCardIndex].isDefault ? "Default" : "Set Default",
                                color: cards[selectedCardIndex].isDefault ? .grocartGreen : .grocartSecondary,
                                isActive: cards[selectedCardIndex].isDefault
                            ) {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    for i in cards.indices {
                                        cards[i].isDefault = i == selectedCardIndex
                                    }
                                }
                            }
                            
                            CardActionButton(
                                icon: "pencil.circle.fill",
                                label: "Edit",
                                color: Color(red: 0.25, green: 0.55, blue: 0.95),
                                isActive: false
                            ) {}
                            
                            CardActionButton(
                                icon: "trash.circle.fill",
                                label: "Remove",
                                color: .red,
                                isActive: false
                            ) {}
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Digital Wallets
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DIGITAL WALLETS")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.grocartSecondary)
                            .tracking(1)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 2) {
                            WalletRow(
                                name: "Apple Pay",
                                icon: "apple.logo",
                                subtitle: "Pay with Face ID",
                                isConnected: true
                            )
                            
                            WalletRow(
                                name: "Google Pay",
                                icon: "g.circle.fill",
                                subtitle: "Not connected",
                                isConnected: false
                            )
                        }
                        .background(Color.grocartSecondaryBackground)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                    }
                    
                    // Add Card
                    Button(action: {}) {
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
    }
}

// MARK: - Credit Card Visual
struct CreditCardView: View {
    let card: PaymentCard
    
    var body: some View {
        ZStack {
            // Card Background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: card.gradientColors,
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
                // Top: Chip + Type
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
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Text(card.lastFour)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Bottom: Name + Expiry + Logo
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CARD HOLDER")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        Text(card.holderName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("EXPIRES")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        Text(card.expiryDate)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Text(card.type.logo)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.leading, 12)
                }
            }
            .padding(24)
        }
        .frame(height: 195)
        .shadow(color: card.gradientColors.first?.opacity(0.3) ?? Color.clear, radius: 15, y: 8)
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

// MARK: - Wallet Row
struct WalletRow: View {
    let name: String
    let icon: String
    let subtitle: String
    let isConnected: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.grocartPrimary)
                .frame(width: 34, height: 34)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.grocartPrimary)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.grocartSecondary)
            }
            
            Spacer()
            
            if isConnected {
                Text("Connected")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.grocartGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.grocartGreen.opacity(0.1)))
            } else {
                Text("Connect")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.grocartSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    NavigationStack {
        PaymentMethodsView()
    }
}
