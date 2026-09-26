//
//  MainTabView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @ObservedObject private var cartManager = CartManager.shared
    
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

                ProfileView()
                    .toolbar(.hidden, for: .tabBar)
                    .tag(3)
            }
            .tint(.grocartGreen)

            // Floating Navigation Bar (Home, Search pill, Cart with badge)
            floatingBottomBar
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToHome)) { _ in
            selectedTab = 0
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
                    .foregroundColor(selectedTab == 0 ? .white : .grocartPrimary)
                    .frame(width: 52, height: 52)
                    .background(selectedTab == 0 ? Color.grocartGreen : Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
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
                .foregroundColor(selectedTab == 1 ? .white : .grocartPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(selectedTab == 1 ? Color.grocartGreen : Color.white)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
            }

            // Cart circular button with badge
            Button(action: {
                selectedTab = 2
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: selectedTab == 2 ? "cart.fill" : "cart")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(selectedTab == 2 ? .white : .grocartPrimary)
                        .frame(width: 52, height: 52)
                        .background(selectedTab == 2 ? Color.grocartGreen : Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

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
    }
}

#Preview {
    MainTabView()
}
