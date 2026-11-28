//
//  ConnectedOrganizerView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 17/11/26.
//

import SwiftUI
import SwiftData

struct ConnectedOrganizerView: View {
    @State private var store: Result<AccountLocalStore, Error>
    @State private var cleanupError = false
    let remote: any ItemRepository
    let captureRepository: any CaptureRepository
    let onSignOut: () -> Void
    let onSessionExpired: () -> Void

    init(account: Account, server: URL, container: Result<ModelContainer, Error>, remote: any ItemRepository,
         captureRepository: any CaptureRepository = SampleCaptureRepository(),
         onSignOut: @escaping () -> Void, onSessionExpired: @escaping () -> Void) {
        self.store = container.map { AccountLocalStore(container: $0, server: server, accountID: account.id) }
        self.remote = remote
        self.captureRepository = captureRepository
        self.onSignOut = onSignOut
        self.onSessionExpired = onSessionExpired
    }

    var body: some View {
        Group {
            switch store {
            case .success(let local):
                RootView(
                    repository: CachedItemRepository(remote: remote, store: local),
                    captureRepository: captureRepository,
                    capabilities: .connected,
                    localStore: local,
                    onSessionExpired: onSessionExpired,
                    onSignOut: {
                        do {
                            try local.purgeAndInvalidate()
                            onSignOut()
                        } catch {
                            cleanupError = true
                        }
                    }
                )
            case .failure:
                ContentUnavailableView {
                    Label("Local storage unavailable", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Restart the app to retry. Your existing data has not been deleted.")
                } actions: {
                    Button("Sign Out", role: .destructive) {
                        onSignOut()
                    }
                }
            }
        }
        .alert("Could not remove local data", isPresented: $cleanupError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try signing out again. Local cleanup must finish before switching accounts.")
        }
    }
}
