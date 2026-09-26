//
//  GrocartInc_IOSApp.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-03.
//

//
//  GrocartInc_IOSApp.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-03.
//

import SwiftUI
import CoreData
import StripePayments
import Security

@main
struct GrocartInc_IOSApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        clearUserDefaultsIfFreshInstall()
        STPAPIClient.shared.publishableKey = APIConfig.stripePublishableKey
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(.light)
        }
    }
}

private func clearUserDefaultsIfFreshInstall() {
    let key = "grocart.installedOnce"
    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: key,
        kSecReturnData: false
    ]

    let exists = SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    guard !exists else { return }

    // Fresh install — wipe any UserDefaults that may have survived a backup restore
    UserDefaults.standard.removeObject(forKey: "grocart.selectedCity")

    // Mark as installed so we don't clear again on next launch
    let addQuery: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrAccount: key,
        kSecValueData: Data([1])
    ]
    SecItemAdd(addQuery as CFDictionary, nil)
}
