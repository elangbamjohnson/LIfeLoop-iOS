import Foundation

struct Account: Codable, Equatable {
    let id: UUID
    let email: String
    let accountStatus: String
    let isAdmin: Bool?
}

@MainActor
protocol AccountRepository {
    func signIn(googleIDToken: String) async throws -> Account
    func currentAccount() async throws -> Account
    func signOut() throws
}
