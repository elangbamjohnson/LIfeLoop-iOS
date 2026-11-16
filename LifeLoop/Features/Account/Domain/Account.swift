import Foundation

struct Account: Decodable, Equatable {
    let id: UUID
    let email: String
    let accountStatus: String
    let isAdmin: Bool?
}

@MainActor
protocol AccountRepository {
    func signIn(email: String, password: String) async throws -> Account
    func currentAccount() async throws -> Account
    func signOut() throws
}
