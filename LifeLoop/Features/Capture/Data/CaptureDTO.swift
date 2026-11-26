//
//  CaptureDTO.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 22/11/26.
//

import Foundation

struct CreateCaptureRequest: Encodable {
    let type: String
    let source: String
    let rawPayload: String
}

struct CaptureResponse: Decodable {
    let capture: CaptureDTO
}

struct CaptureListResponse: Decodable {
    let captures: [CaptureDTO]
}

struct CaptureActionResponse: Decodable {
    let success: Bool?
    let message: String?
}

struct CaptureDTO: Decodable {
    let id: UUID
    let source: String?
    let type: String
    let rawPayload: String
    let originalFilename: String?
    let mimeType: String?
    let processingStatus: String?
    let retryCount: Int?
    let metadata: [String: JSONValue]?
    let createdAt: String?
    let updatedAt: String?

    func domainValue() -> Capture {
        let status = CaptureProcessingStatus(rawValue: processingStatus ?? "pending")
        var createdDate: Date? = nil
        var updatedDate: Date? = nil
        if let createdAt {
            createdDate = LifeItem.parseDate(createdAt)
        }
        if let updatedAt {
            updatedDate = LifeItem.parseDate(updatedAt)
        }

        return Capture(
            id: id,
            source: source ?? "web",
            type: type,
            rawPayload: rawPayload,
            originalFilename: originalFilename,
            mimeType: mimeType,
            processingStatus: status,
            retryCount: retryCount ?? 0,
            metadata: metadata ?? [:],
            createdAt: createdDate,
            updatedAt: updatedDate
        )
    }
}
