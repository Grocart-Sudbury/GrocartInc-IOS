//
//  MainTabView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI
import Combine

struct MainTabView: View {
    @State private var selectedTab = 0
    @ObservedObject private var cartManager = CartManager.shared
    @ObservedObject private var tabBarManager = TabBarManager.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeTabView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(0)
                
                SearchView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(1)

                CartView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(2)

                NavigationStack {
                    ProfileView()
                }
                    .toolbar(.hidden, for: .tabBar)
                    .tag(3)
            }
            .tint(.grocartGreen)

            // Floating Navigation Bar (Home, Search pill, Cart with badge).
            // It hides whenever a page asks for it (e.g. Profile, product
            // and store pages) and pops back up everywhere else.
            if !tabBarManager.isHidden {
                floatingBottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToHome)) { _ in
            tabBarManager.reset()
            selectedTab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToCart)) { _ in
            selectedTab = 2
        }
    }

    // MARK: - Floating Bottom Bar
    private var floatingBottomBar: some View {
        HStack(spacing: 12) {
            // Home circular button
            Button(action: {
                selectedTab = 0
            }) {
                Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(selectedTab == 0 ? .grocartNavy : .grocartPrimary)
                    .frame(width: 52, height: 52)
                    .background(selectedTab == 0 ? Color.grocartGreen : Color.clear)
                    .clipShape(Circle())
            }

            // Search pill button
            Button(action: {
                selectedTab = 1
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Search")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(selectedTab == 1 ? .grocartNavy : .grocartPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(selectedTab == 1 ? Color.grocartGreen : Color.clear)
                .clipShape(Capsule())
            }

            // Cart circular button with badge
            Button(action: {
                selectedTab = 2
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: selectedTab == 2 ? "cart.fill" : "cart")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(selectedTab == 2 ? .grocartNavy : .grocartPrimary)
                        .frame(width: 52, height: 52)
                        .background(selectedTab == 2 ? Color.grocartGreen : Color.clear)
                        .clipShape(Circle())

                    if cartManager.itemCount > 0 {
                        Text("\(cartManager.itemCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 4, y: -4)
                    }
                }
            }
        }
        .padding(6)
        .glassPill()
    }
}

// MARK: - Tab Bar Manager
final class TabBarManager: ObservableObject {
    static let shared = TabBarManager()
    
    @Published var isHidden: Bool = false
    private var hideTokens: Set<String> = []

    private init() {}

    func hide(token: String) {
        hideTokens.insert(token)
        updateVisibility()
    }

    func show(token: String) {
        hideTokens.remove(token)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateVisibility()
        }
    }

    func reset() {
        hideTokens.removeAll()
        updateVisibility()
    }

    private func updateVisibility() {
        let shouldHide = !hideTokens.isEmpty
        if isHidden != shouldHide {
            withAnimation(.easeInOut(duration: 0.25)) {
                isHidden = shouldHide
            }
        }
    }
}

// MARK: - Hide Floating Bottom Bar View Modifier
struct HideFloatingBottomBarModifier: ViewModifier {
    @State private var token = UUID().uuidString

    func body(content: Content) -> some View {
        content
            .onAppear {
                TabBarManager.shared.hide(token: token)
            }
            .onDisappear {
                TabBarManager.shared.show(token: token)
            }
    }
}

extension View {
    func hideFloatingBottomBar() -> some View {
        self.modifier(HideFloatingBottomBarModifier())
    }
}

#Preview {
    MainTabView()
}
