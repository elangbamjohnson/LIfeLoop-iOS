//
//  AccountViewModel.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 16/11/26.
//

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
    private let googleIdentity: any GoogleIdentityProvider
    private var generation = 0

    init(repository: any AccountRepository, googleIdentity: any GoogleIdentityProvider) {
        self.repository = repository
        self.googleIdentity = googleIdentity
    }

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

    func signInWithGoogle() async {
        guard !isBusy else { return }
        generation += 1
        let currentGeneration = generation
        isBusy = true
        errorMessage = nil
        defer { if currentGeneration == generation { isBusy = false } }
        do {
            let token = try await googleIdentity.signIn()
            try Task.checkCancellation()
            guard currentGeneration == generation else { return }
            let account = try await repository.signIn(googleIDToken: token)
            try Task.checkCancellation()
            guard currentGeneration == generation else { return }
            state = .signedIn(account)
        } catch {
            guard currentGeneration == generation else { return }
            if error is CancellationError || Task.isCancelled { return }
            googleIdentity.signOut()
            errorMessage = (error as? GoogleSignInFailure)?.errorDescription
                ?? (error as? APIError)?.errorDescription
                ?? "Could not sign in to LifeLoop. Please try again."
        }
    }

    func handleUnauthorized() {
        try? repository.signOut()
        googleIdentity.signOut()
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
            googleIdentity.signOut()
            state = .signedOut
            errorMessage = nil
        } catch {
            errorMessage = "Could not remove this device's session. Please try signing out again."
        }
    }
}
