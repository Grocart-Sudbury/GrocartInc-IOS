//
//  LocalScratchCardOverlay.swift
//  GrocartInc-IOS
//
//  Scratch-card reveal for the locally generated scratch cards
//  (ScratchCardManager). Reuses the scratch layer and confetti from
//  MyCouponsView. A winner shows its prize and can be used at
//  checkout; a "better luck next time" card shows no prize and no
//  code. Scratching marks the card scratched in the manager.
//

import SwiftUI

struct LocalScratchCardOverlay: View {
    let card: ScratchCard
    let onDismiss: () -> Void
    let onScratched: () -> Void

    @State private var scratchPoints: [CGPoint] = []
    @State private var isRevealed = false
    @State private var revealProgress: CGFloat = 0
    @State private var showConfetti = false

    private let cardWidth: CGFloat = 300
    private let cardHeight: CGFloat = 380

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    if isRevealed { onDismiss() }
                }

            VStack(spacing: 20) {
                ZStack {
                    // Reward underneath
                    LocalRewardContent(card: card)
                        .frame(width: cardWidth, height: cardHeight)
                        .cornerRadius(24)

                    // Scratch layer on top
                    if !isRevealed {
                        ScratchLayer(
                            scratchPoints: $scratchPoints,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            gradientColors: card.gradientColors,
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

                if isRevealed {
                    VStack(spacing: 10) {
                        if card.isWinner {
                            Text("You can use this at checkout.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        Button(action: onDismiss) {
                            Text("Done")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: cardWidth, height: 50)
                                .background(
                                    LinearGradient(
                                        colors: card.gradientColors,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(14)
                        }
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

                Button(action: onDismiss) {
                    Text(isRevealed ? "Maybe Later" : "Close")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 4)
            }

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
        onScratched()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(card.isWinner ? .success : .warning)

        if card.isWinner {
            withAnimation(.easeOut(duration: 0.3)) {
                showConfetti = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation { showConfetti = false }
            }
        }
    }
}

// MARK: - Reward Content (under the scratch layer)
private struct LocalRewardContent: View {
    let card: ScratchCard

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.98, blue: 0.97), .white],
                startPoint: .top,
                endPoint: .bottom
            )

            GeometryReader { geo in
                ForEach(0..<6, id: \.self) { _ in
                    Circle()
                        .fill(card.gradientColors.first?.opacity(0.04) ?? Color.clear)
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

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: card.gradientColors.map { $0.opacity(0.15) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)

                    Image(systemName: card.isWinner ? "gift.fill" : "cloud.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(
                            LinearGradient(
                                colors: card.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text(card.isWinner ? "🎉 Congratulations!" : "Better luck next time")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.grocartSecondary)

                Text(card.displayDiscount)
                    .font(.system(size: card.isWinner ? 36 : 24, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(
                            colors: card.gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Text(card.displayDescription)
                    .font(.system(size: 14))
                    .foregroundColor(.grocartSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if card.isWinner {
                    VStack(spacing: 6) {
                        Text("YOUR CODE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.grocartSecondary)
                            .tracking(1.5)

                        Text(card.code)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.grocartPrimary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: card.gradientColors,
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                                    )
                                    .background(
                                        card.gradientColors.first?.opacity(0.05)
                                            .cornerRadius(10)
                                    )
                            )
                    }
                    .padding(.top, 4)
                }

                HStack(spacing: 20) {
                    VStack(spacing: 2) {
                        Text("Min. Order")
                            .font(.system(size: 10))
                            .foregroundColor(.grocartSecondary)
                        Text("$20")
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
                        Text(card.formattedExpiry)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.grocartPrimary)
                    }
                }

                Spacer()
            }
        }
    }
}
