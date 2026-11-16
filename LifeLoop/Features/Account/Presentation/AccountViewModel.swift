import Foundation
import Observation

@MainActor
@Observable
final class AccountViewModel {
    enum State {
        case restoring
        case signedOut
        case signedIn(Account)
    }
    private(set) var state: State = .restoring
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    private let repository: any AccountRepository
    private var generation = 0

    init(repository: any AccountRepository) { self.repository = repository }

    func restore() async {
        guard case .restoring = state else { return }
        let currentGeneration = generation
        do {
            let account = try await repository.currentAccount()
            try Task.checkCancellation()
            guard currentGeneration == generation else { return }
            state = .signedIn(account)
        } catch {
            guard currentGeneration == generation else { return }
            if error is CancellationError || Task.isCancelled { return }
            state = .signedOut
            if case APIError.unauthorized = error { return }
            errorMessage = "Your session could not be restored. Please sign in again."
        }
    }

    func signIn(email: String, password: String) async {
        guard !isBusy else { return }
        generation += 1
        let currentGeneration = generation
        isBusy = true
        errorMessage = nil
        defer { if currentGeneration == generation { isBusy = false } }
        do {
            let account = try await repository.signIn(email: email, password: password)
            try Task.checkCancellation()
            guard currentGeneration == generation else { return }
            state = .signedIn(account)
        } catch {
            guard currentGeneration == generation else { return }
            if error is CancellationError || Task.isCancelled { return }
            errorMessage = (error as? APIError)?.errorDescription
                ?? "Could not sign in. Check your connection and try again."
        }
    }

    func handleUnauthorized() {
        try? repository.signOut()
        isBusy = false
        state = .signedOut
        errorMessage = "Your session has expired. Please sign in again."
        generation += 1
    }

    func signOut() {
        generation += 1
        isBusy = false
        do {
            try repository.signOut()
            state = .signedOut
            errorMessage = nil
        } catch {
            errorMessage = "Could not remove this device's session. Please try signing out again."
        }
    }
}
