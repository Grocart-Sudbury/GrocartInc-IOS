// ProfileView.swift
// GrocartInc-IOS

import SwiftUI

struct ProfileView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileVM = ProfileViewModel()
    @ObservedObject private var sessionManager = SessionManager.shared
    @ObservedObject private var pointsManager = PointsManager.shared
    @State private var showSignOutAlert = false
    @State private var showEditProfile = false
    @State private var showDeleteWarning1 = false
    @State private var showDeleteWarning2 = false
    @State private var deleteConfirmText = ""
    @State private var isDeletingAccount = false
    @State private var showLogin = false
    @State private var showSignUp = false

    private var user: User? { sessionManager.currentUser }

    private let menuItems: [(String, String, Color, AnyView)] = [
        ("bag.fill",         "My Orders",           .grocartGreen,                    AnyView(MyOrdersView())),
        ("chart.bar.fill",   "Sales Report",        Color(red: 0.35, green: 0.45, blue: 0.6), AnyView(SalesReportView())),
        ("repeat.circle.fill","Subscriptions",        .purple,                          AnyView(SubscriptionListView())),
        ("mappin.circle.fill","Delivery Addresses",  Color(red: 0.2, green: 0.6, blue: 0.9), AnyView(DeliveryAddressesView())),
        ("creditcard.fill",  "Cards",                Color(red: 0.15, green: 0.35, blue: 0.75), AnyView(PaymentMethodsView())),
        ("ticket.fill",      "My Coupons",           .orange,                          AnyView(MyCouponsView()))
    ]

    var body: some View {
        ZStack {
                Color.grocartBackground.ignoresSafeArea()

                if !sessionManager.isLoggedIn {
                    guestView
                } else {
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

                        // Points — tap to see the points earned per purchase
                        NavigationLink(destination: PointsHistoryView()) {
                            VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(Color.grocartGreen.opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.grocartGreen)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("My Points")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.grocartPrimary)
                                    Text("\(pointsManager.points) points")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.grocartPrimary)
                                }
                                Spacer()
                                if pointsManager.canRedeem {
                                    Text("$5 OFF")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.grocartGreen)
                                        .cornerRadius(20)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.grocartSecondary)
                            }

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
                                 ? "You can redeem $5 off your next order at checkout."
                                 : "\(pointsManager.pointsToNextReward) more points to unlock $5 off. Earn 1 point per $1 spent.")
                                .font(.system(size: 12))
                                .foregroundColor(.grocartSecondary)
                        }
                        .padding(16)
                        .background(Color.grocartSecondaryBackground)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        }
                        .buttonStyle(.plain)

                        // Menu Items
                        VStack(spacing: 2) {
                            ForEach(menuItems, id: \.1) { icon, title, color, destination in
                                NavigationLink(destination: destination) {
                                    MenuRow(icon: icon, title: title, color: color)
                                }
                            }
                            Button {
                                if let url = URL(string: "https://grocartinc.ca/support") {
                                    openURL(url)
                                }
                            } label: {
                                MenuRow(icon: "questionmark.circle.fill", title: "Support", color: .purple)
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

                        // Delete Account
                        Button(action: { showDeleteWarning1 = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "trash.fill")
                                Text("Delete Account")
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red.opacity(0.06))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 20)

                        Text("GroCart v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.15")")
                            .font(.system(size: 12))
                            .foregroundColor(.grocartSecondary)
                            .padding(.bottom, 20)
                    }
                }
                } // end else (logged in)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // The tab bar is hidden on Profile, so this is the way back Home.
                // Dismiss pops Profile when it was pushed from Home; the
                // notification switches to the Home tab when it was the tab.
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        dismiss()
                        NotificationCenter.default.post(name: .navigateToHome, object: nil)
                    }) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.grocartGreen)
                    }
                }
            }
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
            // Stage 1 — first warning
            .alert("Delete Account?", isPresented: $showDeleteWarning1) {
                Button("Continue", role: .destructive) {
                    showDeleteWarning1 = false
                    showDeleteWarning2 = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account, all orders, saved addresses, and payment information. This action cannot be undone.")
            }
            // Stage 2 — type DELETE to confirm
            .sheet(isPresented: $showDeleteWarning2) {
                DeleteConfirmSheet(
                    isDeletingAccount: $isDeletingAccount,
                    onCancel: {
                        deleteConfirmText = ""
                        showDeleteWarning2 = false
                    },
                    onConfirm: {
                        showDeleteWarning2 = false
                        Task {
                            isDeletingAccount = true
                            do {
                                try await CustomerRepository.shared.deleteAccount()
                                SessionManager.shared.clearSession()
                            } catch {
                                isDeletingAccount = false
                            }
                        }
                    }
                )
                .presentationDetents([.height(380)])
                .presentationCornerRadius(24)
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView()
            }
        // The tab bar stays hidden on Profile — whether it was reached
        // from the Profile tab or pushed from Home — and pops back up
        // on every other page.
        .hideFloatingBottomBar()
    }

    // MARK: - Guest View
    private var guestView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.grocartGreen.opacity(0.1))
                        .frame(width: 100, height: 100)
                    Image(systemName: "person.fill")
                        .font(.system(size: 42))
                        .foregroundColor(.grocartGreen)
                }

                VStack(spacing: 8) {
                    Text("Welcome to GroCart")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.grocartPrimary)
                    Text("Sign in to view your profile, orders, and saved addresses.")
                        .font(.system(size: 14))
                        .foregroundColor(.grocartSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            VStack(spacing: 14) {
                Button(action: { showLogin = true }) {
                    Text("Sign In")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.grocartGreen)
                        .cornerRadius(14)
                }

                Button(action: { showSignUp = true }) {
                    Text("Create Account")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.grocartGreen)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.grocartGreen.opacity(0.1))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.grocartGreen.opacity(0.3), lineWidth: 1.5)
                        )
                }
            }
            .padding(.horizontal, 24)

            Spacer()
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

// MARK: - Delete Confirm Sheet
struct DeleteConfirmSheet: View {
    @Binding var isDeletingAccount: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var typed = ""

    private var canConfirm: Bool { typed == "DELETE" }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 64, height: 64)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.red)
                }
                .padding(.top, 8)

                VStack(spacing: 8) {
                    Text("Final Warning")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    Text("All your data will be permanently erased and cannot be recovered.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Type DELETE to confirm")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    TextField("", text: $typed)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(height: 48)
                        .background(Color.red.opacity(0.06))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(canConfirm ? Color.red.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1.5)
                        )
                }
                .padding(.horizontal, 4)

                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color(.systemGray6))
                            .cornerRadius(14)
                    }

                    Button(action: onConfirm) {
                        Group {
                            if isDeletingAccount {
                                ProgressView().tint(.white)
                            } else {
                                Text("Delete Forever")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(canConfirm ? Color.red : Color.red.opacity(0.3))
                        .cornerRadius(14)
                    }
                    .disabled(!canConfirm || isDeletingAccount)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    ProfileView()
}
