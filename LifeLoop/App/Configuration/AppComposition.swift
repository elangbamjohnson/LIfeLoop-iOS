import Foundation

/// Construct concrete services once, then inject the narrow interfaces screens need.
final class AppComposition {
    let configuration: AppConfiguration?
    let connected: ConnectedServices?

    init(values: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        configuration = try? AppConfiguration(values: values)
        if let url = configuration?.apiBaseURL {
            connected = ConnectedServices(baseURL: url)
        } else {
            connected = nil
        }
    }
}

final class ConnectedServices {
    let accountRepository: APIAccountRepository
    let itemRepository: APIItemRepository

    init(baseURL: URL) {
        let client = APIClient(
            baseURL: baseURL,
            transport: URLSessionTransport(),
            credentials: KeychainSessionCredentialStore(server: baseURL)
        )
        accountRepository = APIAccountRepository(client: client)
        itemRepository = APIItemRepository(client: client)
    }
}
