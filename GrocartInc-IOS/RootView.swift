//
//  RootView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-09.
//

import SwiftUI

struct RootView: View {
    @StateObject private var sessionManager = SessionManager.shared
    
    var body: some View {
        Group {
            if sessionManager.isLoggedIn {
                // Replace with your main TabView / HomeView
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: sessionManager.isLoggedIn)
    }
}
