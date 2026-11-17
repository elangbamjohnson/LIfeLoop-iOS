import Foundation

final class APIAccountRepository: AccountRepository {
    private let client: APIClient

    init(client: APIClient) { self.client = client }

    func signIn(googleIDToken: String) async throws -> Account {
        guard !googleIDToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GoogleSignInFailure.missingToken
        }
        try client.clearSession()
        let body = try JSONEncoder().encode(GoogleLoginRequest(
            credential: googleIDToken, timezone: TimeZone.current.identifier
        ))
        let (data, response) = try await client.request(
            "api/v1/auth/google", method: "POST", body: body, authenticated: false
        )
        let account = try decodeAccount(data)
        try client.saveSession(from: response, account: account)
        return account
    }

    func currentAccount() async throws -> Account {
        do {
            let (data, _) = try await client.request("api/v1/auth/me")
            return try decodeAccount(data)
        } catch let error as APIError where error == .unauthorized || error == .forbidden {
            try client.clearSession()
            throw error
        } catch let error as URLError where CachedItemRepository.canUseCache(error) {
            guard let account = try client.offlineAccount() else { throw error }
            return account
        }
    }

    func signOut() throws {
        // The inspected backend's logout only clears its cookie; it does not revoke JWTs.
        // Clear our credential and invalidate pending responses immediately.
        try client.clearSession()
    }

    private func decodeAccount(_ data: Data) throws -> Account {
        let account = try JSONDecoder().decode(AccountResponse.self, from: data).user
        guard account.accountStatus == "active" else { throw APIError.forbidden }
        return account
    }

    private struct GoogleLoginRequest: Encodable { let credential: String; let timezone: String }
    private struct AccountResponse: Decodable { let user: Account }
}
