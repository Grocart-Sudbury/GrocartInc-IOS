//
//  OnboardingView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

// MARK: - Onboarding Data Model
struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let iconSecondary: String
    let title: String
    let subtitle: String
    let highlight: String
    let features: [OnboardingFeature]
    let gradientColors: [Color]
}

struct OnboardingFeature: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}

// MARK: - Main Onboarding View
struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showHome = false
    @Environment(\.dismiss) private var dismiss
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "percent",
            iconSecondary: "flame.fill",
            title: "Daily Discounts\n& Promotions",
            subtitle: "Open the app every day to discover fresh deals on groceries you already buy. New promotions drop daily — never pay full price again.",
            highlight: "New deals added every morning",
            features: [
                OnboardingFeature(icon: "calendar.badge.clock", text: "Fresh daily discounts on top items"),
                OnboardingFeature(icon: "cart.fill.badge.plus", text: "Buy more, save more bundles"),
                OnboardingFeature(icon: "star.fill", text: "Loyalty points on every order")
            ],
            gradientColors: [Color.grocartGreen, Color.grocartGreen.opacity(0.7)]
        ),
        OnboardingPage(
            icon: "gift.fill",
            iconSecondary: "sparkles",
            title: "App-Exclusive\nDeals & Offers",
            subtitle: "Unlock special offers you won't find anywhere else. Exclusive to the GroCart app — our way of rewarding you for shopping smart.",
            highlight: "Up to 40% off app-only deals",
            features: [
                OnboardingFeature(icon: "lock.open.fill", text: "Members-only weekly specials"),
                OnboardingFeature(icon: "bag.fill", text: "Free delivery on first 3 orders"),
                OnboardingFeature(icon: "crown.fill", text: "Early access to seasonal sales")
            ],
            gradientColors: [Color(red: 0.2, green: 0.6, blue: 0.9), Color(red: 0.1, green: 0.4, blue: 0.8)]
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            iconSecondary: "tag.fill",
            title: "Price Drops\n& Coupon Codes",
            subtitle: "Get instant notifications when prices drop on your favourites. Plus, receive exclusive coupon codes straight to your phone.",
            highlight: "Never miss a deal again",
            features: [
                OnboardingFeature(icon: "arrow.down.circle.fill", text: "Real-time price drop alerts"),
                OnboardingFeature(icon: "ticket.fill", text: "Exclusive coupon codes every week"),
                OnboardingFeature(icon: "heart.fill", text: "Track prices on your saved items")
            ],
            gradientColors: [Color(red: 0.95, green: 0.55, blue: 0.2), Color(red: 0.9, green: 0.35, blue: 0.15)]
        )
    ]
    
    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button(action: {
                        showHome = true
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
                                .fill(index == currentPage ? Color.grocartGreen : Color.gray.opacity(0.3))
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
                            showHome = true
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                                .font(.system(size: 17, weight: .semibold))
                            
                            Image(systemName: currentPage < pages.count - 1 ? "arrow.right" : "checkmark")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: pages[currentPage].gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: pages[currentPage].gradientColors[0].opacity(0.4), radius: 12, y: 6)
                    }
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
        .fullScreenCover(isPresented: $showHome) {
            MainTabView()
        }
    }
}

// MARK: - Individual Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Icon Section
            ZStack {
                // Background glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [page.gradientColors[0].opacity(0.15), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 70
                        )
                    )
                    .frame(width: 150, height: 150)
                    .scaleEffect(appeared ? 1.0 : 0.5)
                
                // Outer ring
                Circle()
                    .stroke(page.gradientColors[0].opacity(0.15), lineWidth: 1.5)
                    .frame(width: 120, height: 120)
                    .scaleEffect(appeared ? 1.0 : 0.8)
                
                // Inner circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: page.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 85, height: 85)
                    .shadow(color: page.gradientColors[0].opacity(0.4), radius: 16, y: 8)
                    .scaleEffect(appeared ? 1.0 : 0.6)
                
                // Main icon
                Image(systemName: page.icon)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundColor(.white)
                    .scaleEffect(appeared ? 1.0 : 0.3)
                
                // Secondary floating icon
                Image(systemName: page.iconSecondary)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(page.gradientColors[0])
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color.grocartBackground)
                            .shadow(color: page.gradientColors[0].opacity(0.2), radius: 8, y: 4)
                    )
                    .offset(x: 42, y: -38)
                    .scaleEffect(appeared ? 1.0 : 0.0)
            }
            
            // Text Content
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
            
            // Highlight Badge
            Text(page.highlight)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(page.gradientColors[0])
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(page.gradientColors[0].opacity(0.1))
                )
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1.0 : 0.8)
            
            // Feature List
            VStack(spacing: 10) {
                ForEach(Array(page.features.enumerated()), id: \.element.id) { index, feature in
                    HStack(spacing: 12) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(page.gradientColors[0])
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(page.gradientColors[0].opacity(0.1))
                            )
                        
                        Text(feature.text)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.grocartPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.grocartSecondaryBackground)
                    )
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
        }
        .onDisappear {
            appeared = false
        }
    }
}

#Preview {
    OnboardingView()
}
