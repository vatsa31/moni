//
//  moniApp.swift
//  moni
//
//  Created by Shrivatsa Kulkarni on 04/06/26.
//

import SwiftUI
import SwiftData

@main
struct moniApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Account.self,
            SpendingCategory.self,
            MoneyTransaction.self,
            MonthlyBudget.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
