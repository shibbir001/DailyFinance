//
//  DailyFinanceApp.swift
//  DailyFinance
//
//  Created by Shibbir on 9/3/26.
//

import SwiftUI
import CoreData

@main
struct DailyFinanceApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
