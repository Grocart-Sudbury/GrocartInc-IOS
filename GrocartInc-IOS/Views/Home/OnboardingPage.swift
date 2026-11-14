//
//  OnboardingPage.swift
//  GrocartInc-IOS
//
//  Welcome pages, shown once on first launch (RootView,
//  hasCompletedOnboarding). Sky blue + cloud white, telling new
//  customers about points, discounts & coupons, and subscriptions.
//  Replaces the old three pages (daily discounts, nearby stores,
//  thank-you note) — 2026-11-13.
//
//  Animations: drifting clouds on a continuous clock, a breathing
//  glow behind the hero icon, a floating secondary badge, staggered
//  feature rows, and a shimmer sweep across the highlight pill.
//  All iOS 16.6 compatible.
//

import SwiftUI
import CoreLocation

// MARK: - Sky palette
private enum WelcomeSky {
    /// Page background: cloud white at the top, pale sky at the bottom.
    static let backgroundTop = Color.white
    static let backgroundMid = Color(red: 0.93, green: 0.97, blue: 1.0)
    static let backgroundBottom = Color(red: 0.76, green: 0.90, blue: 0.99)
    /// Hero circle gradient, light sky → deep sky.
    static let heroLight = Color.grocartGreen          // #89CFF0
    static let heroDeep = Color.grocartDarkGreen       // #3EA3DC
    static let cloud = Color.white
}

// MARK: - Onboarding Data Model
struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let iconSecondary: String
    let title: String
    let subtitle: String
    let highlight: String
    let features: [OnboardingFeature]
    /// Accent for this page's button, dots and icons.
    let accent: Color
}

struct OnboardingFeature: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}

// MARK: - Main Onboarding View
struct OnboardingView: View {
    @State private var currentPage = 0
    var onComplete: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "star.fill",
            iconSecondary: "sparkles",
            title: "Earn Points\non Every Order",
            subtitle: "Every order earns you points — 100 points is $1 off your next shop. Points land in your account as soon as your payment succeeds.",
            highlight: "100 points = $1.00 off",
            features: [
                OnboardingFeature(icon: "gift.fill", text: "500 welcome points for every account"),
                OnboardingFeature(icon: "star.fill", text: "1 point for every $1 you spend"),
                OnboardingFeature(icon: "dollarsign.circle.fill", text: "Redeem from 100 points, any amount up to your full balance"),
                OnboardingFeature(icon: "box.truck.fill", text: "Points arrive as soon as you pay")
            ],
            accent: Color(red: 0.24, green: 0.64, blue: 0.86)
        ),
        OnboardingPage(
            icon: "percent",
            iconSecondary: "gift.fill",
            title: "Discounts, Coupons\n& Scratch Cards",
            subtitle: "Fresh deals drop every day, plus promo codes at checkout — and every order earns you a scratch card with a surprise inside.",
            highlight: "A scratch card after every order",
            features: [
                OnboardingFeature(icon: "calendar.badge.clock", text: "Fresh daily discounts on top items"),
                OnboardingFeature(icon: "ticket.fill", text: "Promo codes at checkout"),
                OnboardingFeature(icon: "gift.fill", text: "Scratch cards: up to 20% off, or a $25 jackpot")
            ],
            accent: Color(red: 0.18, green: 0.61, blue: 0.91)
        ),
        OnboardingPage(
            icon: "repeat",
            iconSecondary: "creditcard.fill",
            title: "Subscribe &\nNever Run Out",
            subtitle: "Pick a store and the items you always need. We deliver on your schedule — weekly, every 2 weeks or monthly — and bill your saved card.",
            highlight: "Your favourites, on repeat",
            features: [
                OnboardingFeature(icon: "calendar.badge.clock", text: "Weekly, every 2 weeks or monthly"),
                OnboardingFeature(icon: "box.truck.fill", text: "Delivery or pickup — your choice"),
                OnboardingFeature(icon: "creditcard.fill", text: "Billed automatically to your saved card")
            ],
            accent: Color(red: 0.12, green: 0.53, blue: 0.82)
        )
    ]

    var body: some View {
        ZStack {
            WelcomeSkyBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button(action: {
                        onComplete()
                    }) {
                        Text("Skip")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.grocartSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.top, 8)
                .padding(.trailing, 8)

                // Page Content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Bottom Section
                VStack(spacing: 24) {
                    // Custom Page Indicator
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? pages[currentPage].accent : Color.gray.opacity(0.3))
                                .frame(width: index == currentPage ? 28 : 8, height: 8)
                                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                        }
                    }

                    // Action Button
                    Button(action: {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            // Ask for location once, as the welcome ends,
                            // so stores can be shown nearest first.
                            LocationManager.shared.requestLocationIfNeeded()
                            onComplete()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                                .font(.system(size: 17, weight: .semibold))

                            Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "checkmark")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .buttonStyle(GlassPrimaryButtonStyle(tint: pages[currentPage].accent))
                    .animation(.easeInOut(duration: 0.3), value: currentPage)

                    // Page count
                    Text("\(currentPage + 1) of \(pages.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.grocartSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Sky background with drifting clouds
private struct WelcomeSkyBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [WelcomeSky.backgroundTop, WelcomeSky.backgroundMid, WelcomeSky.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            DriftingClouds()
        }
    }
}

private struct DriftingClouds: View {
    /// Each cloud: width, height fraction, drift speed, phase, opacity.
    private let clouds: [(width: CGFloat, y: CGFloat, speed: CGFloat, phase: CGFloat, opacity: Double)] = [
        (150, 0.10, 9, 0, 0.95),
        (110, 0.22, 14, 200, 0.8),
        (190, 0.38, 7, 420, 0.7),
        (120, 0.55, 12, 90, 0.85),
        (170, 0.72, 8, 300, 0.6)
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(Array(clouds.enumerated()), id: \.offset) { _, cloud in
                        // Drift left to right, wrapping seamlessly.
                        let span = geo.size.width + cloud.width * 2
                        let x = -cloud.width + CGFloat((t * Double(cloud.speed) + Double(cloud.phase)).truncatingRemainder(dividingBy: Double(span)))
                        CloudView(width: cloud.width)
                            .opacity(cloud.opacity)
                            .position(x: x, y: geo.size.height * cloud.y)
                    }
                }
            }
        }
    }
}

private struct CloudView: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            Circle()
                .frame(width: width * 0.45, height: width * 0.45)
                .offset(x: -width * 0.22, y: -width * 0.06)
            Circle()
                .frame(width: width * 0.58, height: width * 0.58)
                .offset(y: -width * 0.08)
            Circle()
                .frame(width: width * 0.4, height: width * 0.4)
                .offset(x: width * 0.24, y: -width * 0.04)
            RoundedRectangle(cornerRadius: width * 0.18)
                .frame(width: width, height: width * 0.3)
        }
        .foregroundColor(WelcomeSky.cloud)
    }
}

// MARK: - Individual Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var appeared = false
    @State private var breathing = false
    @State private var shimmerX: CGFloat = -160

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon Section — breathing glow, sky gradient circle,
            // floating secondary badge.
            ZStack {
                // Breathing glow behind the hero circle.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [page.accent.opacity(0.28), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 90
                        )
                    )
                    .frame(width: 190, height: 190)
                    .scaleEffect(breathing ? 1.12 : 0.94)
                    .opacity(breathing ? 0.9 : 0.6)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: breathing)

                Circle()
                    .stroke(page.accent.opacity(0.18), lineWidth: 1.5)
                    .frame(width: 120, height: 120)
                    .scaleEffect(appeared ? 1.0 : 0.8)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [WelcomeSky.heroLight, page.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 85, height: 85)
                    .shadow(color: page.accent.opacity(0.4), radius: 16, y: 8)
                    .scaleEffect(appeared ? 1.0 : 0.6)

                Image(systemName: page.icon)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundColor(.white)
                    .scaleEffect(appeared ? 1.0 : 0.3)

                // Floating secondary badge, gently bobbing.
                Image(systemName: page.iconSecondary)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(page.accent)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .shadow(color: page.accent.opacity(0.2), radius: 8, y: 4)
                    )
                    .offset(x: 42, y: -38)
                    .scaleEffect(appeared ? 1.0 : 0.0)
                    .offset(y: breathing ? -6 : 6)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: breathing)
            }

            VStack(spacing: 10) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.grocartPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Text(page.subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.grocartSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
            }

            // Highlight pill with a slow shimmer sweep.
            Text(page.highlight)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(page.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    ZStack {
                        Capsule()
                            .fill(page.accent.opacity(0.1))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.75), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 60)
                            .offset(x: shimmerX)
                    }
                    .clipShape(Capsule())
                )
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1.0 : 0.8)

            VStack(spacing: 10) {
                ForEach(Array(page.features.enumerated()), id: \.element.id) { index, feature in
                    HStack(spacing: 12) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(page.accent)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(page.accent.opacity(0.1))
                            )

                        Text(feature.text)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.grocartPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassCard(cornerRadius: 16)
                    .opacity(appeared ? 1 : 0)
                    .offset(x: appeared ? 0 : 30)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.1 + 0.3),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appeared = true
            }
            breathing = true
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                shimmerX = 160
            }
        }
        .onDisappear {
            appeared = false
            breathing = false
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
