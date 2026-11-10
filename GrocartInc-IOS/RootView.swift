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

    // Launch splash — baby blue with the black Grocart logo.
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView(onComplete: {
                        hasCompletedOnboarding = true
                    })
                } else {
                    MainTabView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            Task {
                // The logo zooms into the home page over ~1.7s; remove
                // the splash once that has finished.
                try? await Task.sleep(nanoseconds: 1_900_000_000)
                showSplash = false
            }
        }
        .alert("Session Expired", isPresented: $sessionManager.sessionExpired) {
            Button("Sign In") {
                sessionManager.sessionExpired = false
                sessionManager.clearSession()
            }
        } message: {
            Text("Your session has expired. Please sign in again.")
        }
    }
}
