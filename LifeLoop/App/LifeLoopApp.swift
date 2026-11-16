//
//  LifeLoopApp.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import SwiftUI

@main
struct LifeLoopApp: App {
    @State private var composition = AppComposition()
    var body: some Scene {
        WindowGroup {
            if let configuration = composition.configuration {
                if configuration.environment == .demo {
                    demoContent
                } else if let services = composition.connected {
                    AccountView(
                        accountRepository: services.accountRepository,
                        itemRepository: services.itemRepository
                    )
                }
            } else {
                ContentUnavailableView(
                    "Server not configured",
                    systemImage: "network.slash",
                    description: Text("This build needs a valid HTTPS server address before it can connect.")
                )
            }
        }
    }

    private var demoContent: some View {
        RootView(repository: demoRepository)
            .safeAreaInset(edge: .bottom) {
                Text("Demo data · Changes reset when the app restarts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
    }

    private var demoRepository: SampleItemRepository {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--empty-items") {
            return SampleItemRepository(items: [])
        }
        if arguments.contains("--failed-items") {
            return SampleItemRepository(items: [], shouldFail: true)
        }
        #endif
        return SampleItemRepository(items: SampleItems.all)
    }
}
