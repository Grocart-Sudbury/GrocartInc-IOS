//
//  WelcomeBackView.swift
//  GrocartInc-IOS
//
//  Full-screen welcome shown right after a successful sign-in:
//  blue gradient, calm water waves along the bottom,
//  "Welcome back" with a small "We missed you" underneath.
//

import SwiftUI

struct WelcomeBackView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Blue gradient background
            LinearGradient(
                colors: [
                    Color.grocartGreen,
                    Color.grocartDarkGreen,
                    Color(red: 23 / 255, green: 84 / 255, blue: 134 / 255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Water waves along the bottom
            VStack {
                Spacer()
                WelcomeWavesView()
                    .frame(height: 190)
            }
            .ignoresSafeArea()

            // Message
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 84, height: 84)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.white)
                }
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.05), value: appeared)

                Text("Welcome back")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.6).delay(0.15), value: appeared)

                Text("We missed you")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.6).delay(0.4), value: appeared)
            }
            .padding(.bottom, 60)
        }
        .onAppear {
            appeared = true
        }
    }
}

// MARK: - Calm water waves (continuous clock, never loops)

private struct WelcomeWavesView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .bottom) {
                WelcomeWaveShape(phase: elapsed * 0.6, amplitude: 14, frequency: 1.5, baseY: 0.45)
                    .fill(Color.white.opacity(0.14))
                WelcomeWaveShape(phase: elapsed * 0.9 + 2, amplitude: 18, frequency: 2, baseY: 0.62)
                    .fill(Color.white.opacity(0.18))
                WelcomeWaveShape(phase: elapsed * 1.2 + 4, amplitude: 12, frequency: 2.5, baseY: 0.78)
                    .fill(Color.white.opacity(0.25))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct WelcomeWaveShape: Shape {
    var phase: Double
    var amplitude: CGFloat
    var frequency: Double
    var baseY: CGFloat

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midY = height * baseY

        path.move(to: CGPoint(x: 0, y: midY))
        for x in stride(from: 0, through: width, by: 2) {
            let relativeX = x / width
            let y = midY + CGFloat(sin(relativeX * .pi * 2 * frequency + phase)) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }
}
