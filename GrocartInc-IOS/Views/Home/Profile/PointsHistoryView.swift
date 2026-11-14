//
//  PointsHistoryView.swift
//  GrocartInc-IOS
//
//  Tapping My Points in Profile opens this: the current balance and,
//  for every purchase, how many points it earned — plus every redemption.
//

import SwiftUI

struct PointsHistoryView: View {
    @ObservedObject private var pointsManager = PointsManager.shared

    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()

            if pointsManager.history.isEmpty {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.grocartGreen.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "star.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.grocartGreen)
                    }
                    Text("No points yet")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.grocartPrimary)
                    Text("Place an order to start earning points. You earn \(pointsManager.rules.earnPointsPerDollar) point per $1 of your order subtotal after discounts, and points land as soon as your payment succeeds. Every account gets \(pointsManager.rules.welcomeBonusPoints) welcome points.")
                        .font(.system(size: 14))
                        .foregroundColor(.grocartSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                List {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Current balance")
                                    .font(.system(size: 13))
                                    .foregroundColor(.grocartSecondary)
                                Text("\(pointsManager.points) points")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.grocartPrimary)
                                Text("Worth \(pointsManager.formattedBalanceValue)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.grocartSecondary)
                                Text("Lifetime: \(pointsManager.lifetimeEarned) earned · \(pointsManager.lifetimeRedeemed) redeemed")
                                    .font(.system(size: 12))
                                    .foregroundColor(.grocartSecondary)
                            }
                            Spacer()
                            if pointsManager.canRedeem {
                                Text("\(pointsManager.formattedBalanceValue) OFF")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.grocartGreen)
                                    .cornerRadius(20)
                            }
                        }
                        .padding(.vertical, 4)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.grocartGreen.opacity(0.15))
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.grocartGreen)
                                    .frame(width: geo.size.width * pointsManager.progressToReward, height: 8)
                            }
                        }
                        .frame(height: 8)

                        Text(pointsManager.canRedeem
                             ? "You can redeem \(pointsManager.formattedBalanceValue) off your next order at checkout."
                             : "\(pointsManager.pointsToNextReward) more points to unlock \(pointsManager.formattedMinRedemptionValue) off.")
                            .font(.system(size: 12))
                            .foregroundColor(.grocartSecondary)

                        if pointsManager.rules.welcomeBonusPoints > 0 {
                            Text("Every account gets \(pointsManager.rules.welcomeBonusPoints) welcome points.")
                                .font(.system(size: 12))
                                .foregroundColor(.grocartSecondary)
                        }
                    }

                    Section("History") {
                        ForEach(pointsManager.history) { tx in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill((tx.isEarned ? Color.grocartGreen : Color.red).opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: tx.isEarned ? "star.fill" : "tag.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(tx.isEarned ? .grocartGreen : .red)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tx.type.displayLabel)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.grocartPrimary)
                                        .lineLimit(1)
                                    Text(tx.label)
                                        .font(.system(size: 12))
                                        .foregroundColor(.grocartSecondary)
                                        .lineLimit(1)
                                    Text(tx.formattedDate)
                                        .font(.system(size: 12))
                                        .foregroundColor(.grocartSecondary)
                                }
                                Spacer()
                                Text(tx.formattedDelta)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(tx.isEarned ? .grocartGreen : .red)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("My Points")
        .navigationBarTitleDisplayMode(.inline)
        // Fresh balance every time the screen opens, so a bonus the
        // server just granted (e.g. the welcome bonus for an older
        // account) shows up instead of the cached summary.
        // NOTE: no refresh on appear here on purpose. Refreshing flips
        // shared PointsManager state while this screen is being pushed,
        // and that pops the screen straight back to Profile. Profile
        // refreshes the balance BEFORE navigating instead.
    }
}
