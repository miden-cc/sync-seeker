//
//  SyncSeekerPadApp.swift
//  SyncSeekerPad
//
//  Created by pancake on 2026/03/07.
//

import SwiftUI
import CoreData

@main
struct SyncSeekerPadApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
