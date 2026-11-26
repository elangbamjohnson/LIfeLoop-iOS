//
//  Capture.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 22/11/26.
//

import Foundation

struct Capture: Identifiable, Equatable, Sendable {
    let id: UUID
    let source: String
    let type: String
    let rawPayload: String
    let originalFilename: String?
    let mimeType: String?
    let processingStatus: CaptureProcessingStatus
    let retryCount: Int
    let metadata: [String: JSONValue]
    let createdAt: Date?
    let updatedAt: Date?

    init(
        id: UUID,
        source: String = "ios",
        type: String = "text",
        rawPayload: String,
        originalFilename: String? = nil,
        mimeType: String? = nil,
        processingStatus: CaptureProcessingStatus = .pending,
        retryCount: Int = 0,
        metadata: [String: JSONValue] = [:],
        createdAt: Date? = Date(),
        updatedAt: Date? = Date()
    ) {
        self.id = id
        self.source = source
        self.type = type
        self.rawPayload = rawPayload
        self.originalFilename = originalFilename
        self.mimeType = mimeType
        self.processingStatus = processingStatus
        self.retryCount = retryCount
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var previewText: String {
        let trimmed = rawPayload.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Empty capture" }
        if let firstLine = trimmed.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            return firstLine.trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }
}
