//
//  APICaptureRepository.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 22/11/26.
//

import Foundation

@MainActor
final class APICaptureRepository: CaptureRepository {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func createCapture(text: String, source: String = "ios") async throws -> Capture {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CaptureValidationError.empty
        }

        // Match JavaScript string.length by checking UTF-16 code units
        let utf16Count = text.utf16.count
        guard utf16Count <= 10_000 else {
            throw CaptureValidationError.tooLong(utf16Count)
        }

        let payload = CreateCaptureRequest(type: "text", source: source, rawPayload: text)
        let body = try JSONEncoder().encode(payload)

        let (responseData, _) = try await client.request(
            "api/v1/captures",
            method: "POST",
            body: body,
            authenticated: true
        )

        let response: CaptureResponse
        do {
            response = try JSONDecoder().decode(CaptureResponse.self, from: responseData)
        } catch {
            throw APIError.invalidResponse
        }

        return response.capture.domainValue()
    }

    func fetchCaptures() async throws -> [Capture] {
        let (responseData, _) = try await client.request(
            "api/v1/captures",
            method: "GET",
            authenticated: true
        )

        let response: CaptureListResponse
        do {
            response = try JSONDecoder().decode(CaptureListResponse.self, from: responseData)
        } catch {
            throw APIError.invalidResponse
        }

        return response.captures.map { $0.domainValue() }
    }
}
