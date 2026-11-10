//
//  MyCouponsView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

// MARK: - Coupon Model
struct Coupon: Identifiable {
    let id: Int
    let code: String
    let discount: String
    let description: String
    let expiryDate: String
    let minimumOrder: String
    let gradientColors: [Color]
    var isScratched: Bool = false
    var isLocked: Bool = false
    var availableFrom: String? = nil
}

private extension PromoCode {
    func toCoupon() -> Coupon {
        let discountText: String
        let descriptionText: String
        let colors: [Color]

        switch rewardType {
        case .percentage:
            discountText = "\(Int(rewardValue))% OFF"
            descriptionText = "Save \(Int(rewardValue))% on your order"
            colors = [Color.orange, Color.red]
        case .flat:
            let flatStr = rewardValue.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", rewardValue)
                : String(format: "%.2f", rewardValue)
            discountText = "$\(flatStr) OFF"
            descriptionText = "Save $\(flatStr) on your order"
            colors = [Color(red: 0.18, green: 0.8, blue: 0.44), Color(red: 0.09, green: 0.63, blue: 0.52)]
        case .freeDelivery:
            discountText = "Free Delivery"
            descriptionText = "No delivery fee on your order"
            colors = [Color(red: 0.20, green: 0.60, blue: 0.86), Color(red: 0.56, green: 0.27, blue: 0.68)]
        case .credits:
            let creditsStr = rewardValue.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", rewardValue)
                : String(format: "%.2f", rewardValue)
            discountText = "$\(creditsStr) Credits"
            descriptionText = "Credits added to your account"
            colors = [Color(red: 0.56, green: 0.27, blue: 0.68), Color(red: 0.93, green: 0.33, blue: 0.66)]
        case .item:
            discountText = rewardItemName ?? "Free Item"
            descriptionText = "Free item added to your order"
            colors = [Color(red: 0.95, green: 0.77, blue: 0.06), Color.orange]
        }

        let expiryText: String
        if let raw = expiresAt {
            let display = DateFormatter()
            display.dateFormat = "MMM d, yyyy"
            let iso = ISO8601DateFormatter()
            let plain = DateFormatter()
            plain.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            plain.locale = Locale(identifier: "en_US_POSIX")
            if let date = iso.date(from: raw) ?? plain.date(from: raw) {
                expiryText = display.string(from: date)
            } else {
                expiryText = "No expiry"
            }
        } else {
            expiryText = "No expiry"
        }

        let minOrder: String
        if let min = minOrderValue, min > 0 {
            let minStr = min.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", min)
                : String(format: "%.2f", min)
            minOrder = "$\(minStr)"
        } else {
            minOrder = "None"
        }

        // Determine lock state from activeFrom
        var isLocked = false
        var availableFromDisplay: String? = nil
        if let raw = activeFrom {
            let iso = ISO8601DateFormatter()
            let plain = DateFormatter()
            plain.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            plain.locale = Locale(identifier: "en_US_POSIX")
            if let unlockDate = iso.date(from: raw) ?? plain.date(from: raw) {
                if unlockDate > Date() {
                    isLocked = true
                    let display = DateFormatter()
                    display.dateFormat = "MMM d, yyyy"
                    availableFromDisplay = display.string(from: unlockDate)
                }
            }
        }

        return Coupon(
            id: id,
            code: code,
            discount: discountText,
            description: descriptionText,
            expiryDate: expiryText,
            minimumOrder: minOrder,
            gradientColors: colors,
            isLocked: isLocked,
            availableFrom: availableFromDisplay
        )
    }
}

// MARK: - My Coupons View
struct MyCouponsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var scratchCardManager = ScratchCardManager.shared
    @State private var coupons: [Coupon] = []
    @State private var selectedCoupon: Coupon?
    @State private var showScratchCard = false
    @State private var selectedScratchCard: ScratchCard?
    @State private var showLocalScratchCard = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .scaleEffect(1.3)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 34))
                        .foregroundColor(.orange.opacity(0.6))
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.grocartSecondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await loadCoupons() } }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.horizontal, 40)
            } else if coupons.isEmpty && scratchCardManager.cards.isEmpty {
                VStack(spacing: 16) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.10))
                            .frame(width: 80, height: 80)
                        Image(systemName: "ticket")
                            .font(.system(size: 34))
                            .foregroundColor(.orange.opacity(0.6))
                    }

                    Text("No coupons right now")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.grocartPrimary)

                    Text("Sorry, there are no coupons available\nat the moment. Check back later!")
                        .font(.system(size: 14))
                        .foregroundColor(.grocartSecondary)
                        .multilineTextAlignment(.center)

                    Spacer()
                }
                .padding(.horizontal, 40)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if !scratchCardManager.cards.isEmpty {
                            HStack {
                                Text("Scratch Cards")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.grocartPrimary)
                                Spacer()
                                Text("Earned after every order")
                                    .font(.system(size: 11))
                                    .foregroundColor(.grocartSecondary)
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, 4)

                            ForEach(scratchCardManager.cards) { card in
                                ScratchCardRow(card: card) {
                                    selectedScratchCard = card
                                    showLocalScratchCard = true
                                }
                            }
                        }

                        if !coupons.isEmpty {
                            if !scratchCardManager.cards.isEmpty {
                                HStack {
                                    Text("Promo Codes")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.grocartPrimary)
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                                .padding(.top, 8)
                            }

                            ForEach(coupons) { coupon in
                                CouponCard(coupon: coupon) {
                                    guard !coupon.isLocked else { return }
                                    selectedCoupon = coupon
                                    showScratchCard = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }

            if showLocalScratchCard, let card = selectedScratchCard {
                LocalScratchCardOverlay(
                    card: card,
                    onDismiss: {
                        showLocalScratchCard = false
                        selectedScratchCard = nil
                    },
                    onScratched: { ScratchCardManager.shared.markScratched(card) }
                )
                .transition(.opacity)
                .zIndex(1)
            }

            if showScratchCard, let coupon = selectedCoupon {
                ScratchCardOverlay(coupon: coupon) {
                    if let index = coupons.firstIndex(where: { $0.id == coupon.id }) {
                        coupons[index].isScratched = true
                    }
                    showScratchCard = false
                    selectedCoupon = nil
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showScratchCard)
        .navigationTitle("My Coupons")
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
        .task { await loadCoupons() }
    }

    private func loadCoupons() async {
        isLoading = true
        errorMessage = nil
        do {
            let promoCodes = try await PromoCodeRepository.shared.fetchCustomerCodes()
            coupons = promoCodes.map { $0.toCoupon() }
            // Schedule unlock notifications for locked coupons and cancel any
            // that have already unlocked since the last visit.
            await CouponNotificationScheduler.scheduleUnlockNotifications(for: promoCodes)
            CouponNotificationScheduler.cancelUnlockNotifications(for: promoCodes)
        } catch {
            errorMessage = "Could not load coupons. Please try again."
        }
        isLoading = false
    }
}

// MARK: - Coupon Card
struct CouponCard: View {
    let coupon: Coupon
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left: Coupon Info
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: coupon.gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)

                        if coupon.isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.9))
                        } else if coupon.isScratched {
                            Image(systemName: "checkmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if coupon.isLocked {
                            Text("Mystery Reward")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.grocartPrimary)
                            if let from = coupon.availableFrom {
                                Text("Unlocks \(from)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.grocartSecondary)
                            }
                        } else if coupon.isScratched {
                            Text(coupon.discount)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.grocartPrimary)
                            Text(coupon.description)
                                .font(.system(size: 12))
                                .foregroundColor(.grocartSecondary)
                        } else {
                            Text("Mystery Reward")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.grocartPrimary)
                            Text("Tap to scratch & reveal")
                                .font(.system(size: 12))
                                .foregroundColor(.grocartSecondary)
                        }
                    }
                }

                Spacer()

                // Right: Action Indicator
                VStack(spacing: 4) {
                    if coupon.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18))
                            .foregroundColor(coupon.gradientColors.first ?? .grocartGreen)
                        Text("Locked")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(coupon.gradientColors.first ?? .grocartGreen)
                    } else if coupon.isScratched {
                        Text(coupon.code)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(coupon.gradientColors.first ?? .grocartGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                (coupon.gradientColors.first ?? .grocartGreen).opacity(0.1)
                            )
                            .cornerRadius(6)

                        Text("Exp: \(coupon.expiryDate)")
                            .font(.system(size: 10))
                            .foregroundColor(.grocartSecondary)
                    } else {
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)

                        Text("Scratch")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(16)
            .background(Color.grocartSecondaryBackground)
            .cornerRadius(16)
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(coupon.isLocked)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !coupon.isLocked {
                        withAnimation(.easeInOut(duration: 0.15)) { isPressed = true }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.15)) { isPressed = false }
                }
        )
    }
}

// MARK: - Scratch Card Row (locally generated cards)
struct ScratchCardRow: View {
    let card: ScratchCard
    let onTap: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
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

                        if card.isUsed {
                            Image(systemName: "checkmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        } else if card.isScratched {
                            Image(systemName: "checkmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if card.isScratched {
                            Text(card.displayDiscount)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.grocartPrimary)
                            Text(card.displayDescription)
                                .font(.system(size: 12))
                                .foregroundColor(.grocartSecondary)
                        } else {
                            Text("Mystery Reward")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.grocartPrimary)
                            Text("Tap to scratch & reveal")
                                .font(.system(size: 12))
                                .foregroundColor(.grocartSecondary)
                        }
                    }
                }

                Spacer()

                VStack(spacing: 4) {
                    if card.isUsed {
                        Text("Used")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.grocartSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.12))
                            .cornerRadius(6)
                        Text("Exp: \(card.formattedExpiry)")
                            .font(.system(size: 10))
                            .foregroundColor(.grocartSecondary)
                    } else if card.isScratched {
                        if card.isWinner {
                            Text(card.code)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(card.gradientColors.first ?? .grocartGreen)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    (card.gradientColors.first ?? .grocartGreen).opacity(0.1)
                                )
                                .cornerRadius(6)
                        }
                        Text("Exp: \(card.formattedExpiry)")
                            .font(.system(size: 10))
                            .foregroundColor(.grocartSecondary)
                    } else {
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)

                        Text("Scratch")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(16)
            .background(Color.grocartSecondaryBackground)
            .cornerRadius(16)
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.15)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.15)) { isPressed = false }
                }
        )
    }
}

// MARK: - Scratch Card Overlay
struct ScratchCardOverlay: View {
    let coupon: Coupon
    let onDismiss: () -> Void
    
    @State private var scratchPoints: [CGPoint] = []
    @State private var isRevealed = false
    @State private var revealProgress: CGFloat = 0
    @State private var showConfetti = false
    @State private var showCopyConfirmation = false
    
    private let cardWidth: CGFloat = 300
    private let cardHeight: CGFloat = 380
    private let scratchThreshold: Int = 80
    
    var body: some View {
        ZStack {
            // Dimmed Background
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    if isRevealed { onDismiss() }
                }
            
            VStack(spacing: 20) {
                // Scratch Card
                ZStack {
                    // Reward Layer (underneath)
                    RewardContent(coupon: coupon, showCopyConfirmation: $showCopyConfirmation)
                        .frame(width: cardWidth, height: cardHeight)
                        .cornerRadius(24)
                    
                    // Scratch Layer (on top)
                    if !isRevealed {
                        ScratchLayer(
                            scratchPoints: $scratchPoints,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            gradientColors: coupon.gradientColors,
                            onScratchProgress: { progress in
                                revealProgress = progress
                                if progress > 0.3 && !isRevealed {
                                    revealCard()
                                }
                            }
                        )
                        .cornerRadius(24)
                        .transition(.opacity)
                    }
                }
                .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 15)
                
                // Instructions / Action Button
                if isRevealed {
                    Button {
                        UIPasteboard.general.string = coupon.code
                        withAnimation(.spring(response: 0.3)) {
                            showCopyConfirmation = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            onDismiss()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: showCopyConfirmation ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            Text(showCopyConfirmation ? "Copied!" : "Copy Code & Apply")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: cardWidth, height: 50)
                        .background(
                            LinearGradient(
                                colors: coupon.gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    VStack(spacing: 6) {
                        Text("Scratch the card to reveal your reward")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("Use your finger to scratch the surface")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .transition(.opacity)
                }
                
                // Close button
                Button(action: onDismiss) {
                    Text(isRevealed ? "Maybe Later" : "Close")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 4)
            }
            
            // Confetti Particles
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
    }
    
    private func revealCard() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            isRevealed = true
        }
        
        // Trigger haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Show confetti
        withAnimation(.easeOut(duration: 0.3)) {
            showConfetti = true
        }
        
        // Hide confetti after a while
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation { showConfetti = false }
        }
    }
}

// MARK: - Reward Content (Under the scratch layer)
struct RewardContent: View {
    let coupon: Coupon
    @Binding var showCopyConfirmation: Bool
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.98, blue: 0.97), .white],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Subtle pattern
            GeometryReader { geo in
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(coupon.gradientColors.first?.opacity(0.04) ?? Color.clear)
                        .frame(width: CGFloat.random(in: 60...120))
                        .offset(
                            x: CGFloat.random(in: -30...geo.size.width),
                            y: CGFloat.random(in: -30...geo.size.height)
                        )
                }
            }
            .clipped()
            
            VStack(spacing: 16) {
                Spacer()
                
                // Trophy/Gift Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: coupon.gradientColors.map { $0.opacity(0.15) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                    
                    Image(systemName: "gift.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(
                            LinearGradient(
                                colors: coupon.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Congratulations
                Text("🎉 Congratulations!")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.grocartSecondary)
                
                // Discount Value
                Text(coupon.discount)
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(
                            colors: coupon.gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text(coupon.description)
                    .font(.system(size: 14))
                    .foregroundColor(.grocartSecondary)
                
                // Code Box
                VStack(spacing: 6) {
                    Text("YOUR CODE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.grocartSecondary)
                        .tracking(1.5)
                    
                    Text(coupon.code)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.grocartPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: coupon.gradientColors,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                                )
                                .background(
                                    coupon.gradientColors.first?.opacity(0.05)
                                        .cornerRadius(10)
                                )
                        )
                }
                .padding(.top, 4)
                
                // Details
                HStack(spacing: 20) {
                    VStack(spacing: 2) {
                        Text("Min. Order")
                            .font(.system(size: 10))
                            .foregroundColor(.grocartSecondary)
                        Text(coupon.minimumOrder)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.grocartPrimary)
                    }
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 1, height: 28)
                    
                    VStack(spacing: 2) {
                        Text("Expires")
                            .font(.system(size: 10))
                            .foregroundColor(.grocartSecondary)
                        Text(coupon.expiryDate)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.grocartPrimary)
                    }
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Scratch Layer
struct ScratchLayer: View {
    @Binding var scratchPoints: [CGPoint]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let gradientColors: [Color]
    let onScratchProgress: (CGFloat) -> Void
    
    @State private var currentLine: [CGPoint] = []
    @State private var lines: [[CGPoint]] = []
    
    var body: some View {
        ZStack {
            // Scratch surface
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Shimmer pattern
            GeometryReader { geo in
                ForEach(0..<8, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: geo.size.width * 1.5, height: 1.5)
                        .rotationEffect(.degrees(-35))
                        .offset(y: CGFloat(i) * 50 - 50)
                }
            }
            .clipped()
            
            // Content on scratch layer
            VStack(spacing: 12) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("SCRATCH HERE")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(2)
                
                Text("Scratch to reveal your reward")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                
                // Scratch progress dots
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(Color.white.opacity(scratchProgress > CGFloat(i) / 5.0 ? 0.9 : 0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: scratchProgress)
                    }
                }
                .padding(.top, 8)
            }
            
            // Scratch mask
            Canvas { context, size in
                for line in lines {
                    var path = Path()
                    guard let first = line.first else { continue }
                    path.move(to: first)
                    for point in line.dropFirst() {
                        path.addLine(to: point)
                    }
                    context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: 50, lineCap: .round, lineJoin: .round))
                }
                
                var currentPath = Path()
                if let first = currentLine.first {
                    currentPath.move(to: first)
                    for point in currentLine.dropFirst() {
                        currentPath.addLine(to: point)
                    }
                    context.stroke(currentPath, with: .color(.black), style: StrokeStyle(lineWidth: 50, lineCap: .round, lineJoin: .round))
                }
            }
            .compositingGroup()
            .blendMode(.destinationOut)
        }
        .compositingGroup()
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let point = value.location
                    currentLine.append(point)
                    scratchPoints.append(point)
                    
                    // Light haptic on scratch
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred(intensity: 0.4)
                    
                    // Calculate progress
                    let progress = calculateScratchProgress()
                    onScratchProgress(progress)
                }
                .onEnded { _ in
                    lines.append(currentLine)
                    currentLine = []
                }
        )
    }
    
    private var scratchProgress: CGFloat {
        calculateScratchProgress()
    }
    
    private func calculateScratchProgress() -> CGFloat {
        // Estimate scratch coverage based on number of unique grid cells covered
        let gridSize: CGFloat = 30
        var coveredCells: Set<String> = []
        
        for point in scratchPoints {
            let cellX = Int(point.x / gridSize)
            let cellY = Int(point.y / gridSize)
            coveredCells.insert("\(cellX),\(cellY)")
        }
        
        let totalCells = Int(cardWidth / gridSize) * Int(cardHeight / gridSize)
        return min(1.0, CGFloat(coveredCells.count) / CGFloat(max(totalCells, 1)))
    }
}

// MARK: - Confetti View
struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    
    struct ConfettiParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        let color: Color
        let size: CGFloat
        let rotation: Double
        let speed: CGFloat
        let horizontalDrift: CGFloat
        let shape: Int // 0 = circle, 1 = rectangle, 2 = triangle-ish
    }
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                for particle in particles {
                    let elapsed = CGFloat(time.truncatingRemainder(dividingBy: 10))
                    let yOffset = particle.speed * elapsed * 60
                    let xOffset = sin(elapsed * 2 + particle.horizontalDrift) * 30 + particle.horizontalDrift * elapsed * 10
                    
                    let currentY = particle.y + yOffset
                    let currentX = particle.x + xOffset
                    
                    guard currentY < size.height + 50 else { continue }
                    
                    let opacity = max(0, 1.0 - (currentY / size.height))
                    let rotation = Angle.degrees(particle.rotation + Double(elapsed) * 120)
                    
                    context.opacity = opacity
                    context.translateBy(x: currentX, y: currentY)
                    context.rotate(by: rotation)
                    
                    let rect = CGRect(x: -particle.size / 2, y: -particle.size / 2, width: particle.size, height: particle.size * (particle.shape == 1 ? 0.5 : 1.0))
                    
                    if particle.shape == 0 {
                        context.fill(Circle().path(in: rect), with: .color(particle.color))
                    } else {
                        context.fill(RoundedRectangle(cornerRadius: 1).path(in: rect), with: .color(particle.color))
                    }
                    
                    context.rotate(by: -rotation)
                    context.translateBy(x: -currentX, y: -currentY)
                    context.opacity = 1.0
                }
            }
        }
        .onAppear {
            generateParticles()
        }
    }
    
    private func generateParticles() {
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .blue, .purple, .pink,
            Color(red: 1.0, green: 0.84, blue: 0.0), // Gold
            Color(red: 0.0, green: 0.9, blue: 0.7)  // Teal
        ]
        
        particles = (0..<60).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 40...UIScreen.main.bounds.width - 40),
                y: CGFloat.random(in: -200...(-20)),
                color: colors.randomElement() ?? .red,
                size: CGFloat.random(in: 5...10),
                rotation: Double.random(in: 0...360),
                speed: CGFloat.random(in: 1.5...4.0),
                horizontalDrift: CGFloat.random(in: -3...3),
                shape: Int.random(in: 0...2)
            )
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        MyCouponsView()
    }
}
