//
//  SplashView.swift
//  GrocartInc-IOS
//
//  Launch splash — baby blue background, black Grocart wordmark.
//  The logo settles in, then zooms in toward the home page as the
//  splash fades away. Shows on every cold launch.
//

import SwiftUI

struct SplashView: View {
    // Enter: logo fades/scales in.
    @State private var logoScale: CGFloat = 0.92
    @State private var logoOpacity: Double = 0
    // Zoom: logo grows toward the home page, splash fades out.
    @State private var zoomScale: CGFloat = 1.0
    @State private var splashOpacity: Double = 1.0

    var body: some View {
        ZStack {
            Color.grocartGreen.ignoresSafeArea()

            Image("GrocartLogo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 240)
                .foregroundColor(.black)
                .scaleEffect(logoScale * zoomScale)
                .opacity(logoOpacity)
        }
        .opacity(splashOpacity)
        .onAppear {
            // Logo settles in.
            withAnimation(.easeOut(duration: 0.5)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            // Hold a beat, then zoom into the home page.
            withAnimation(.easeIn(duration: 0.7).delay(1.0)) {
                zoomScale = 3.2
            }
            withAnimation(.easeOut(duration: 0.7).delay(1.0)) {
                splashOpacity = 0
            }
        }
    }
}
