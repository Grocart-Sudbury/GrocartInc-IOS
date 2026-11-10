//
//  CityPickerSheet.swift
//  GrocartInc-IOS
//
//  City picker as a rounded square box in the middle of the screen —
//  transparent black box, white writing. Tapping outside the box
//  closes it.
//

import SwiftUI

struct CityPickerSheet: View {
    @ObservedObject private var locationState = LocationState.shared
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            // Dim the screen; tap outside the box to close.
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            // Rounded square box, centred.
            VStack(alignment: .leading, spacing: 0) {
                Text("Choose Your City")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Text("Select your delivery city.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 4)

                VStack(spacing: 0) {
                    ForEach(City.allCases, id: \.self) { city in
                        Button(action: {
                            locationState.cityName = city.displayName
                            isPresented = false
                        }) {
                            HStack {
                                Text(city.displayName)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                if locationState.cityName == city.displayName {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.plain)

                        if city != City.allCases.last {
                            Divider()
                                .background(Color.white.opacity(0.15))
                        }
                    }
                }
                .padding(.top, 16)

                Spacer()

                Button(action: { isPresented = false }) {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .frame(width: 320, height: 340)
            .background(Color.black.opacity(0.85))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 24, x: 0, y: 12)
        }
    }
}
