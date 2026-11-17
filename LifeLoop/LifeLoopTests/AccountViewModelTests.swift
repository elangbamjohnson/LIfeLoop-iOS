import Foundation
import Testing
@testable import LifeLoop

@MainActor
struct AccountViewModelTests {
    @Test func expiredSessionShowsSignIn() async {
        let model = AccountViewModel(repository: AccountStub(), googleIdentity: GoogleIdentityStub())
        await model.restore()
        guard case .signedOut = model.state else { Issue.record("Expected sign-in screen"); return }
        #expect(model.errorMessage == nil)
    }

    @Test func signInExchangesGoogleTokenAndSignOutClearsBothSessions() async {
        let repository = AccountStub()
        let google = GoogleIdentityStub()
        let model = AccountViewModel(repository: repository, googleIdentity: google)
        await model.restore()
        await model.signInWithGoogle()
        guard case .signedIn(let account) = model.state else { Issue.record("Expected account"); return }
        #expect(account.id == repository.account.id)
        #expect(repository.receivedToken == "google-id-token")
        #expect(!model.isBusy)
        model.signOut()
        guard case .signedOut = model.state else { Issue.record("Expected sign-out"); return }
        #expect(repository.didSignOut)
        #expect(google.didSignOut)
    }

    @Test func failedBackendLoginKeepsScreenAvailableAndClearsGoogleSession() async {
        let repository = AccountStub()
        repository.shouldFail = true
        let google = GoogleIdentityStub()
        let model = AccountViewModel(repository: repository, googleIdentity: google)
        await model.restore()
        await model.signInWithGoogle()
        guard case .signedOut = model.state else { Issue.record("Expected sign-in screen"); return }
        #expect(model.errorMessage != nil)
        #expect(!model.isBusy)
        #expect(google.didSignOut)
    }

    @Test func cancelingGoogleDoesNotCallBackendOrShowAnError() async {
        let repository = AccountStub()
        let google = GoogleIdentityStub()
        google.failure = CancellationError()
        let model = AccountViewModel(repository: repository, googleIdentity: google)
        await model.restore()
        await model.signInWithGoogle()
        guard case .signedOut = model.state else { Issue.record("Expected sign-in screen"); return }
        #expect(repository.receivedToken == nil)
        #expect(model.errorMessage == nil)
        #expect(!model.isBusy)
    }

    @Test func missingGoogleConfigurationShowsUsefulErrorWithoutBackendCall() async {
        let repository = AccountStub()
        let google = GoogleIdentityStub()
        google.failure = GoogleSignInFailure.missingConfiguration
        let model = AccountViewModel(repository: repository, googleIdentity: google)
        await model.restore()
        await model.signInWithGoogle()
        #expect(repository.receivedToken == nil)
        #expect(model.errorMessage == GoogleSignInFailure.missingConfiguration.errorDescription)
        #expect(!model.isBusy)
    }

    @Test func restoredLifeLoopSessionDoesNotRequireGoogleSignIn() async {
        let repository = AccountStub()
        repository.hasSession = true
        let google = GoogleIdentityStub()
        let model = AccountViewModel(repository: repository, googleIdentity: google)
        await model.restore()
        guard case .signedIn(let account) = model.state else { Issue.record("Expected restored account"); return }
        #expect(account.id == repository.account.id)
        #expect(google.signInCount == 0)
    }

    @Test func repeatedTapAndLateGoogleResultCannotUndoSignOut() async {
        let repository = AccountStub()
        let google = GoogleIdentityStub()
        google.shouldSuspend = true
        let model = AccountViewModel(repository: repository, googleIdentity: google)
        await model.restore()
        let pendingSignIn = Task { await model.signInWithGoogle() }
        // Wait until the fake provider has entered its suspended sign-in operation.
        while google.pendingResult == nil { await Task.yield() }
        #expect(model.isBusy)
        await model.signInWithGoogle()
        #expect(google.signInCount == 1)
        model.signOut()
        google.pendingResult?.resume(returning: "late-token")
        await pendingSignIn.value
        guard case .signedOut = model.state else { Issue.record("Late result restored account"); return }
        #expect(repository.receivedToken == nil)
        #expect(!model.isBusy)
    }
}

@MainActor
private final class AccountStub: AccountRepository {
    let account = Account(id: UUID(), email: "reader@example.com", accountStatus: "active", isAdmin: false)
    var shouldFail = false
    var hasSession = false
    var didSignOut = false
    var receivedToken: String?
    func currentAccount() async throws -> Account {
        guard hasSession else { throw APIError.unauthorized }
        return account
    }
    func signIn(googleIDToken: String) async throws -> Account {
        receivedToken = googleIDToken
        if shouldFail { throw APIError.unauthorized }
        return account
    }
    func signOut() throws { didSignOut = true }
}

@MainActor
private final class GoogleIdentityStub: GoogleIdentityProvider {
    var failure: Error?
    var didSignOut = false
    var signInCount = 0
    var shouldSuspend = false
    var pendingResult: CheckedContinuation<String, Never>?
    func signIn() async throws -> String {
        signInCount += 1
        if let failure { throw failure }
        if shouldSuspend {
            return await withCheckedContinuation { pendingResult = $0 }
        }
        return "google-id-token"
    }
    func signOut() { didSignOut = true }
}
