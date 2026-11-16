import SwiftUI
import SwiftData

struct ConnectedOrganizerView: View {
    @State private var store: Result<AccountLocalStore, Error>
    @State private var cleanupError = false
    let remote: any ItemRepository
    let onSignOut: () -> Void
    let onSessionExpired: () -> Void

    init(account: Account, server: URL, container: Result<ModelContainer, Error>, remote: any ItemRepository,
         onSignOut: @escaping () -> Void, onSessionExpired: @escaping () -> Void) {
        self.store = container.map { AccountLocalStore(container: $0, server: server, accountID: account.id) }
        self.remote = remote
        self.onSignOut = onSignOut
        self.onSessionExpired = onSessionExpired
    }

    var body: some View {
        Group {
            switch store {
            case .success(let local):
                RootView(repository: CachedItemRepository(remote: remote, store: local), allowsEditing: false,
                         localStore: local, onSessionExpired: onSessionExpired)
                    .safeAreaInset(edge: .bottom) {
                        Button("Sign out and remove local data") {
                            do {
                                try local.purgeAndInvalidate()
                                onSignOut()
                            } catch { cleanupError = true }
                        }
                        .padding().frame(maxWidth: .infinity).background(.bar)
                    }
            case .failure:
                ContentUnavailableView("Local storage unavailable", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text("Restart the app to retry. Your existing data has not been deleted."))
            }
        }
        .alert("Could not remove local data", isPresented: $cleanupError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try signing out again. Local cleanup must finish before switching accounts.")
        }
    }
}
