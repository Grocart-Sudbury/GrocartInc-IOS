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

@main
struct GrocartInc_IOSApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        STPAPIClient.shared.publishableKey = APIConfig.stripePublishableKey
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
