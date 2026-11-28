//
//  AppComposition.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 16/11/26.
//

import Foundation
import SwiftData

/// Construct concrete services once, then inject the narrow interfaces screens need.
final class AppComposition {
    let configuration: AppConfiguration?
    let connected: ConnectedServices?
    let demoStore: Result<AccountLocalStore, Error>?

    init(values: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        configuration = try? AppConfiguration(values: values)
        if configuration?.environment == .demo {
            demoStore = Result {
                let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
                return AccountLocalStore(container: try AccountLocalStore.makeContainer(inMemory: testing),
                                         server: URL(string: "lifeloop-demo://local")!,
                                         accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!)
            }
        } else { demoStore = nil }
        if let url = configuration?.apiBaseURL {
            connected = ConnectedServices(baseURL: url)
        } else {
            connected = nil
        }
    }
}

final class ConnectedServices {
    let server: URL
    let container: Result<ModelContainer, Error>
    let accountRepository: APIAccountRepository
    let itemRepository: APIItemRepository
    let captureRepository: APICaptureRepository

    init(baseURL: URL) {
        server = baseURL
        container = Result { try AccountLocalStore.makeContainer() }
        let client = APIClient(
            baseURL: baseURL,
            transport: URLSessionTransport(),
            credentials: KeychainSessionCredentialStore(server: baseURL)
        )
        accountRepository = APIAccountRepository(client: client)
        itemRepository = APIItemRepository(client: client)
        captureRepository = APICaptureRepository(client: client)
    }
}
