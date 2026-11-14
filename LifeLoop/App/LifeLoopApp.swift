//
//  LifeLoopApp.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import SwiftUI

@main
struct LifeLoopApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(
                repository: SampleItemRepository(items: SampleItems.all)
            )
        }
    }
}
