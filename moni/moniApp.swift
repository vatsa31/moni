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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(FinanceStore.sharedModelContainer)
    }
}
