//
//  APIClient.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 16/11/26.
//

import Foundation

@MainActor
protocol HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Cookies and credentials are handled explicitly, never through a shared cookie jar.
final class URLSessionTransport: NSObject, HTTPTransport, URLSessionTaskDelegate {
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        return (data, response)
    }

    // An API redirect must never forward session credentials to a different endpoint.
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

enum APIError: Error, LocalizedError, Equatable {
    case unauthorized
    case forbidden
    case conflict
    case rateLimited
    case server(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized: "Your sign-in could not be verified. Please sign in again."
        case .forbidden: "Your account does not have access to this action."
        case .conflict: "This item has changed. Refresh it before trying again."
        case .rateLimited: "Too many attempts. Please wait before trying again."
        case .server: "The server could not complete the request. Please try again."
        case .invalidResponse: "The server returned a response this app could not read."
        }
    }
}

@MainActor
final class APIClient {
    let baseURL: URL
    private let transport: any HTTPTransport
    private let credentials: any SessionCredentialStore
    private var generation = 0

    init(baseURL: URL, transport: any HTTPTransport, credentials: any SessionCredentialStore) {
        self.baseURL = baseURL
        self.transport = transport
        self.credentials = credentials
    }

    func request(
        _ path: String,
        method: String = "GET",
        body: Data? = nil,
        authenticated: Bool = true
    ) async throws -> (Data, HTTPURLResponse) {
        let requestGeneration = generation
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(TimeZone.current.identifier, forHTTPHeaderField: "X-Timezone")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if authenticated {
            guard let credential = try credentials.read(), credential.expiresAt > Date() else {
                throw APIError.unauthorized
            }
            request.setValue("session=\(credential.token)", forHTTPHeaderField: "Cookie")
        }
        let (data, response) = try await transport.send(request)
        try Task.checkCancellation()
        // A response from a signed-out session may never repopulate the next account.
        guard requestGeneration == generation else { throw CancellationError() }
        switch response.statusCode {
        case 200..<300: return (data, response)
        case 401: throw APIError.unauthorized
        case 403: throw APIError.forbidden
        case 409, 412: throw APIError.conflict
        case 429: throw APIError.rateLimited
        default: throw APIError.server(response.statusCode)
        }
    }

    func saveSession(from response: HTTPURLResponse, account: Account? = nil) throws {
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, entry in
            result[String(describing: entry.key)] = String(describing: entry.value)
        }
        guard let cookie = HTTPCookie.cookies(withResponseHeaderFields: headers, for: baseURL)
            .first(where: { $0.name == "session" }),
              let expiry = cookie.expiresDate, expiry > Date(), !cookie.value.isEmpty else {
            throw APIError.invalidResponse
        }
        try credentials.save(SessionCredential(token: cookie.value, expiresAt: expiry, account: account))
    }

    func offlineAccount() throws -> Account? {
        guard let credential = try credentials.read(), credential.expiresAt > Date(),
              credential.account?.accountStatus == "active" else { return nil }
        return credential.account
    }

    func clearSession() throws {
        generation += 1
        try credentials.clear()
    }
}
