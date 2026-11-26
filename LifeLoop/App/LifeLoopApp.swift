//
//  LifeLoopApp.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import SwiftUI
import GoogleSignIn

@main
struct LifeLoopApp: App {
    @State private var composition = AppComposition()
    var body: some Scene {
        WindowGroup {
            Group {
                if let configuration = composition.configuration {
                    if configuration.environment == .demo {
                        demoContent
                    } else if let services = composition.connected {
                        AccountView(
                            accountRepository: services.accountRepository,
                            itemRepository: services.itemRepository,
                            captureRepository: services.captureRepository,
                            server: services.server, container: services.container
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
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }

    private var demoContent: some View {
        Group {
            if case .success(let store) = composition.demoStore {
                RootView(repository: demoRepository, captureRepository: demoCaptureRepository, localStore: store)
            } else {
                ContentUnavailableView("Local storage unavailable", systemImage: "externaldrive.badge.exclamationmark")
            }
        }
    }

    private var demoCaptureRepository: SampleCaptureRepository {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let repository = arguments.contains("--empty-captures")
            ? SampleCaptureRepository(captures: []) : SampleCaptureRepository()
        repository.shouldFail = arguments.contains("--failed-captures")
        repository.failNextSubmission = arguments.contains("--fail-first-capture")
        repository.shouldFailMutation = arguments.contains("--fail-capture-action")
        return repository
        #else
        return SampleCaptureRepository()
        #endif
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
