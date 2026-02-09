//
//  ProfileView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

//
//  ProfileView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

struct ProfileView: View {
    private let menuItems: [(String, String, Color)] = [
        ("bag.fill", "My Orders", .grocartGreen),
        ("mappin.circle.fill", "Delivery Addresses", Color(red: 0.2, green: 0.6, blue: 0.9)),
        ("creditcard.fill", "Payment Methods", .purple),
        ("ticket.fill", "My Coupons", .orange),
        ("bell.fill", "Notifications", .red),
        ("gearshape.fill", "Settings", .gray)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.grocartBackground.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Profile Header
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.grocartGreen.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.grocartGreen)
                            }
                            
                            VStack(spacing: 4) {
                                Text("John Doe")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.grocartPrimary)
                                
                                Text("john.doe@email.com")
                                    .font(.system(size: 14))
                                    .foregroundColor(.grocartSecondary)
                            }
                            
                            Button(action: {}) {
                                Text("Edit Profile")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.grocartGreen)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .stroke(Color.grocartGreen, lineWidth: 1.5)
                                    )
                            }
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                        
                        // Stats Row
                        HStack(spacing: 0) {
                            ProfileStat(value: "12", label: "Orders")
                            
                            Divider()
                                .frame(height: 40)
                            
                            ProfileStat(value: "$48", label: "Saved")
                            
                            Divider()
                                .frame(height: 40)
                            
                            ProfileStat(value: "3", label: "Coupons")
                        }
                        .padding(.vertical, 16)
                        .background(Color.grocartSecondaryBackground)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        
                        // Menu Items
                        VStack(spacing: 2) {
                            ForEach(menuItems, id: \.1) { icon, title, color in
                                HStack(spacing: 14) {
                                    Image(systemName: icon)
                                        .font(.system(size: 15))
                                        .foregroundColor(color)
                                        .frame(width: 34, height: 34)
                                        .background(color.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    Text(title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.grocartPrimary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.grocartSecondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                        }
                        .background(Color.grocartSecondaryBackground)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        
                        // Sign Out
                        Button(action: {}) {
                            HStack(spacing: 8) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(14)
                        }
                        .padding(.horizontal, 20)
                        
                        Text("GroCart v1.0.0")
                            .font(.system(size: 12))
                            .foregroundColor(.grocartSecondary)
                            .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Profile Stat
struct ProfileStat: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.grocartPrimary)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.grocartSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProfileView()
}
