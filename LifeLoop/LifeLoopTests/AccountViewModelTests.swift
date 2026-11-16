import Foundation
import Testing
@testable import LifeLoop

@MainActor
struct AccountViewModelTests {
    @Test func expiredSessionShowsSignIn() async {
        let repository = AccountStub()
        let model = AccountViewModel(repository: repository)
        await model.restore()
        guard case .signedOut = model.state else { Issue.record("Expected sign-in form"); return }
        #expect(model.errorMessage == nil)
    }

    @Test func signInAndSignOutChangeAccountState() async throws {
        let repository = AccountStub()
        let model = AccountViewModel(repository: repository)
        await model.restore()
        await model.signIn(email: "reader@example.com", password: "test")
        guard case .signedIn(let account) = model.state else { Issue.record("Expected account"); return }
        #expect(account.id == repository.account.id)
        #expect(!model.isBusy)
        model.signOut()
        guard case .signedOut = model.state else { Issue.record("Expected sign-out"); return }
        #expect(repository.didSignOut)
    }

    @Test func failedLoginKeepsFormAvailable() async {
        let repository = AccountStub()
        repository.shouldFail = true
        let model = AccountViewModel(repository: repository)
        await model.restore()
        await model.signIn(email: "reader@example.com", password: "wrong")
        guard case .signedOut = model.state else { Issue.record("Expected sign-in form"); return }
        #expect(model.errorMessage != nil)
        #expect(!model.isBusy)
    }
}

@MainActor
private final class AccountStub: AccountRepository {
    let account = Account(id: UUID(), email: "reader@example.com", accountStatus: "active", isAdmin: false)
    var shouldFail = false
    var didSignOut = false
    func currentAccount() async throws -> Account { throw APIError.unauthorized }
    func signIn(email: String, password: String) async throws -> Account {
        if shouldFail { throw APIError.unauthorized }
        return account
    }
    func signOut() throws { didSignOut = true }
}
