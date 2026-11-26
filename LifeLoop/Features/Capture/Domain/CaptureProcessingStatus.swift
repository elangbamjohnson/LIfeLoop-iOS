//
//  CaptureProcessingStatus.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 22/11/26.
//

import SwiftUI

enum CaptureProcessingStatus: Equatable, Sendable {
    case pending
    case processing
    case completed
    case failed
    case fallbackPendingRetry
    case unknown(String)

    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "pending": self = .pending
        case "processing": self = .processing
        case "completed": self = .completed
        case "failed": self = .failed
        case "fallback_pending_retry": self = .fallbackPendingRetry
        default: self = .unknown(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .pending: return "pending"
        case .processing: return "processing"
        case .completed: return "completed"
        case .failed: return "failed"
        case .fallbackPendingRetry: return "fallback_pending_retry"
        case .unknown(let val): return val
        }
    }

    var isActive: Bool {
        switch self {
        case .pending, .processing, .fallbackPendingRetry:
            return true
        case .completed, .failed, .unknown:
            return false
        }
    }

    var displayLabel: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Organized"
        case .failed: return "Failed"
        case .fallbackPendingRetry: return "Retrying"
        case .unknown(let val): return val.capitalized
        }
    }

    var systemImage: String {
        switch self {
        case .pending: return "clock"
        case .processing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .fallbackPendingRetry: return "arrow.clockwise"
        case .unknown: return "questionmark.circle"
        }
    }

    var tintColor: Color {
        switch self {
        case .pending: return .secondary
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        case .fallbackPendingRetry: return .orange
        case .unknown: return .gray
        }
    }
}
