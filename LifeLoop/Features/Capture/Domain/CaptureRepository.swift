//
//  CaptureRepository.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 22/11/26.
//

import Foundation

enum CaptureValidationError: Error, LocalizedError, Equatable {
    case empty
    case tooLong(Int)

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Please enter text before capturing."
        case .tooLong(let length):
            return "Text payload exceeds maximum allowed length of 10,000 characters (\(length) characters)."
        }
    }
}

@MainActor
protocol CaptureRepository: AnyObject {
    func createCapture(text: String, source: String) async throws -> Capture
    func fetchCaptures() async throws -> [Capture]
    func retryCapture(id: UUID) async throws
    func deleteCapture(id: UUID) async throws
}

extension CaptureRepository {
    func createCapture(text: String) async throws -> Capture {
        try await createCapture(text: text, source: "ios")
    }
}
