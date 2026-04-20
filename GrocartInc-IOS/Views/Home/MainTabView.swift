//
//  MainTabView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeTabView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)
            
            SearchView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    Text("Search")
                }
                .tag(1)

            CartView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "cart.fill" : "cart")
                    Text("Cart")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(3)
        }
        .tint(.grocartGreen)
    }
}

#Preview {
    MainTabView()
}
