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

@main
struct GrocartInc_IOSApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            LoginView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
