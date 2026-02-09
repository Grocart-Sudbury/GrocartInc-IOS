//
//  SettingsView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

//
//  SettingsView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pushNotifications = true
    @State private var orderUpdates = true
    @State private var promoAlerts = false
    @State private var darkMode = false
    @State private var biometricAuth = true
    @State private var locationServices = true
    @State private var showDeleteAlert = false
    
    var body: some View {
        ZStack {
            Color.grocartBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Account Section
                    SettingsSection(title: "Account") {
                        VStack(spacing: 0) {
                            SettingsNavigationRow(
                                icon: "person.fill",
                                title: "Personal Information",
                                subtitle: "Name, email, phone",
                                color: .grocartGreen
                            )
                            
                            SettingsDivider()
                            
                            SettingsNavigationRow(
                                icon: "lock.fill",
                                title: "Change Password",
                                subtitle: "Last changed 30 days ago",
                                color: Color(red: 0.25, green: 0.55, blue: 0.95)
                            )
                            
                            SettingsDivider()
                            
                            SettingsNavigationRow(
                                icon: "globe",
                                title: "Language",
                                subtitle: "English",
                                color: .purple
                            )
                        }
                    }
                    
                    // Notifications Section
                    SettingsSection(title: "Notifications") {
                        VStack(spacing: 0) {
                            SettingsToggleRow(
                                icon: "bell.fill",
                                title: "Push Notifications",
                                color: .red,
                                isOn: $pushNotifications
                            )
                            
                            SettingsDivider()
                            
                            SettingsToggleRow(
                                icon: "truck.box.fill",
                                title: "Order Updates",
                                color: Color(red: 0.25, green: 0.55, blue: 0.95),
                                isOn: $orderUpdates
                            )
                            
                            SettingsDivider()
                            
                            SettingsToggleRow(
                                icon: "tag.fill",
                                title: "Promotional Alerts",
                                color: .orange,
                                isOn: $promoAlerts
                            )
                        }
                    }
                    
                    // Preferences Section
                    SettingsSection(title: "Preferences") {
                        VStack(spacing: 0) {
                            SettingsToggleRow(
                                icon: "moon.fill",
                                title: "Dark Mode",
                                color: Color(red: 0.35, green: 0.35, blue: 0.55),
                                isOn: $darkMode
                            )
                            
                            SettingsDivider()
                            
                            SettingsToggleRow(
                                icon: "faceid",
                                title: "Face ID / Touch ID",
                                color: .grocartGreen,
                                isOn: $biometricAuth
                            )
                            
                            SettingsDivider()
                            
                            SettingsToggleRow(
                                icon: "location.fill",
                                title: "Location Services",
                                color: Color(red: 0.25, green: 0.55, blue: 0.95),
                                isOn: $locationServices
                            )
                        }
                    }
                    
                    // Support Section
                    SettingsSection(title: "Support") {
                        VStack(spacing: 0) {
                            SettingsNavigationRow(
                                icon: "questionmark.circle.fill",
                                title: "Help Center",
                                subtitle: "FAQs & guides",
                                color: .grocartGreen
                            )
                            
                            SettingsDivider()
                            
                            SettingsNavigationRow(
                                icon: "message.fill",
                                title: "Contact Support",
                                subtitle: "Chat or email us",
                                color: Color(red: 0.25, green: 0.55, blue: 0.95)
                            )
                            
                            SettingsDivider()
                            
                            SettingsNavigationRow(
                                icon: "star.fill",
                                title: "Rate GroCart",
                                subtitle: "Love the app? Leave a review!",
                                color: .orange
                            )
                        }
                    }
                    
                    // Legal Section
                    SettingsSection(title: "Legal") {
                        VStack(spacing: 0) {
                            SettingsNavigationRow(
                                icon: "doc.text.fill",
                                title: "Terms of Service",
                                subtitle: nil,
                                color: .gray
                            )
                            
                            SettingsDivider()
                            
                            SettingsNavigationRow(
                                icon: "hand.raised.fill",
                                title: "Privacy Policy",
                                subtitle: nil,
                                color: .gray
                            )
                            
                            SettingsDivider()
                            
                            SettingsNavigationRow(
                                icon: "info.circle.fill",
                                title: "Licenses",
                                subtitle: nil,
                                color: .gray
                            )
                        }
                    }
                    
                    // Danger Zone
                    VStack(spacing: 10) {
                        Button(action: { showDeleteAlert = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 14))
                                Text("Delete Account")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.red.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.06))
                            .cornerRadius(12)
                        }
                        
                        Text("GroCart v1.0.0 (Build 42)")
                            .font(.system(size: 11))
                            .foregroundColor(.grocartSecondary.opacity(0.6))
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
                .padding(.top, 10)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.grocartPrimary)
                }
            }
        }
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {}
        } message: {
            Text("This will permanently delete your account, order history, and all saved data. This action cannot be undone.")
        }
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.grocartSecondary)
                .tracking(1)
                .padding(.horizontal, 20)
            
            content
                .background(Color.grocartSecondaryBackground)
                .cornerRadius(16)
                .padding(.horizontal, 20)
        }
    }
}

// MARK: - Settings Divider
struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.1))
            .frame(height: 0.5)
            .padding(.leading, 60)
    }
}

// MARK: - Settings Navigation Row
struct SettingsNavigationRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let color: Color
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.grocartPrimary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.grocartSecondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.grocartSecondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
    }
}

// MARK: - Settings Toggle Row
struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let color: Color
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.grocartPrimary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(.grocartGreen)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
