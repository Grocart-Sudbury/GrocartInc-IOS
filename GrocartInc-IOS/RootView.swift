//
//  RootView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-11.
//

import SwiftUI

struct RootView: View {
    @StateObject private var sessionManager = SessionManager.shared
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some View {
        Group {
            if !sessionManager.isLoggedIn {
                LoginView()
            } else if !hasCompletedOnboarding {
                OnboardingView(onComplete: {
                    hasCompletedOnboarding = true
                })
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: sessionManager.isLoggedIn)
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
    }
}
