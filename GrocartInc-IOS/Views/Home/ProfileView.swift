// ProfileView.swift
// GrocartInc-IOS

import SwiftUI

struct ProfileView: View {
    @StateObject private var profileVM = ProfileViewModel()
    @State private var showSignOutAlert = false
    @State private var showEditProfile = false

    private var user: User? { SessionManager.shared.currentUser }

    private let menuItems: [(String, String, Color, AnyView)] = [
        ("bag.fill",         "My Orders",           .grocartGreen,                    AnyView(MyOrdersView())),
        ("mappin.circle.fill","Delivery Addresses",  Color(red: 0.2, green: 0.6, blue: 0.9), AnyView(DeliveryAddressesView())),
        ("ticket.fill",      "My Coupons",           .orange,                          AnyView(MyCouponsView()))
    ]

    var body: some View {
        NavigationStack {
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
                                if profileVM.isLoading && profileVM.profile == nil {
                                    ProgressView()
                                } else {
                                    let name = profileVM.profile?.fullName ?? user?.fullName ?? "—"
                                    let email = profileVM.profile?.email ?? user?.email ?? "—"
                                    Text(name)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.grocartPrimary)
                                    Text(email)
                                        .font(.system(size: 14))
                                        .foregroundColor(.grocartSecondary)
                                    if let phone = profileVM.profile?.phone, !phone.isEmpty {
                                        Text(phone)
                                            .font(.system(size: 13))
                                            .foregroundColor(.grocartSecondary)
                                    }
                                }
                            }

                            Button(action: { showEditProfile = true }) {
                                Text("Edit Profile")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.grocartGreen)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().stroke(Color.grocartGreen, lineWidth: 1.5)
                                    )
                            }
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 10)

                        // Menu Items
                        VStack(spacing: 2) {
                            ForEach(menuItems, id: \.1) { icon, title, color, destination in
                                NavigationLink(destination: destination) {
                                    MenuRow(icon: icon, title: title, color: color)
                                }
                            }
                        }
                        .background(Color.grocartSecondaryBackground)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)

                        // Sign Out
                        Button(action: { showSignOutAlert = true }) {
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
            .onAppear { profileVM.load() }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(viewModel: profileVM)
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Sign Out", role: .destructive) {
                    SessionManager.shared.clearSession()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

// MARK: - Menu Row
struct MenuRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
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
