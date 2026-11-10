//
//  GlassStyle.swift
//  GrocartInc-IOS
//
//  Apple Liquid Glass style for Grocart.
//  On iOS 26+ this uses the real Liquid Glass effect (.glassEffect);
//  on older iOS it falls back to a frosted material, so the look holds
//  on every iPhone the app supports. The baby blue theme (#89CFF0)
//  is the tint throughout.
//

import SwiftUI

// MARK: - Glass card / pill

private struct GlassSurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(tint.opacity(0.20)).interactive(),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 6)
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 6)
        }
    }
}

private struct GlassCapsuleModifier: ViewModifier {
    var tint: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(tint.opacity(0.20)).interactive(), in: Capsule())
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 6)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.55), lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 6)
        }
    }
}

extension View {
    /// Frosted glass card (Liquid Glass on iOS 26, frosted material below).
    func glassCard(cornerRadius: CGFloat = 24, tint: Color = .grocartGreen) -> some View {
        modifier(GlassSurfaceModifier(cornerRadius: cornerRadius, tint: tint))
    }

    /// Frosted glass capsule — for the tab bar, pills and chips.
    func glassPill(tint: Color = .grocartGreen) -> some View {
        modifier(GlassCapsuleModifier(tint: tint))
    }
}

// MARK: - Glass primary button

struct GlassPrimaryButtonStyle: ButtonStyle {
    var tint: Color = .grocartGreen

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.grocartNavy)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .glassCard(cornerRadius: 18, tint: tint)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassPrimaryButtonStyle {
    static var glassPrimary: GlassPrimaryButtonStyle { GlassPrimaryButtonStyle() }
}

// MARK: - Black primary button (Add to Cart on glass)

struct BlackPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.black)
            .cornerRadius(18)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BlackPrimaryButtonStyle {
    static var blackPrimary: BlackPrimaryButtonStyle { BlackPrimaryButtonStyle() }
}

// MARK: - Soft glass background

private struct GlassBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            LinearGradient(
                colors: [
                    Color.grocartGreen.opacity(0.30),
                    Color.white,
                    Color(red: 0.92, green: 0.95, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

extension View {
    /// Soft baby-blue glass backdrop for a screen (replaces the flat background).
    func glassBackground() -> some View {
        modifier(GlassBackgroundModifier())
    }

    /// Transparent backdrop for product screens — no blue tint, so the
    /// clear-glass product cards read as transparent.
    func clearGlassBackground() -> some View {
        modifier(ClearGlassBackgroundModifier())
    }
}

// MARK: - Clear glass background (transparent, no blue)

private struct ClearGlassBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            ZStack {
                // Pearl-silver diagonal sheen, like light through frosted glass —
                // gives the clear-glass cards something to refract against.
                LinearGradient(
                    colors: [
                        .white,
                        Color(red: 0.95, green: 0.95, blue: 0.96),
                        Color(red: 0.89, green: 0.90, blue: 0.92),
                        Color(red: 0.97, green: 0.97, blue: 0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Soft pool of light at the top
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.85),
                        Color.white.opacity(0)
                    ],
                    center: .top,
                    startRadius: 20,
                    endRadius: 520
                )
            }
            .ignoresSafeArea()
        )
    }
}
