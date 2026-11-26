import Foundation
import Observation

@MainActor
@Observable
final class CaptureViewModel {
    private(set) var captures: [Capture] = []
    private(set) var isLoading = false
    private(set) var isSubmitting = false
    private(set) var requiresSignIn = false
    private(set) var errorMessage: String?
    private(set) var lastLoadedAt: Date?

    var onItemsNeedsRefresh: (() async -> Void)?
    var onSessionExpired: (() -> Void)?

    private let repository: any CaptureRepository
    private let waitForNextPoll: () async throws -> Void
    private let maxPollIterations: Int
    private var isForegroundActive = false
    private var generation = 0
    private var activeLoadTask: Task<Void, Never>?
    private var activeLoadID: UUID?
    private var submissionID: UUID?
    private var pollingTask: Task<Void, Never>?
    private var pollingID: UUID?

    init(
        repository: any CaptureRepository,
        maxPollIterations: Int = 30,
        waitForNextPoll: @escaping () async throws -> Void = {
            try await Task.sleep(for: .seconds(4))
        }
    ) {
        self.repository = repository
        self.maxPollIterations = maxPollIterations
        self.waitForNextPoll = waitForNextPoll
    }

    var hasActiveCaptures: Bool {
        captures.contains { $0.processingStatus.isActive }
    }

    func setForegroundActive(_ active: Bool) {
        isForegroundActive = active
        if !active {
            stopPolling()
            cancelLoad()
        }
    }

    /// All callers await the same fetch, reconciliation, and Organizer refresh.
    func loadCaptures() async {
        guard isForegroundActive, !requiresSignIn, !Task.isCancelled else { return }
        if let activeLoadTask {
            await activeLoadTask.value
            return
        }

        let requestID = UUID()
        let requestGeneration = generation
        let knownIDs = Set(captures.map(\.id))
        activeLoadID = requestID
        isLoading = true
        let task = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.activeLoadID == requestID {
                    self.activeLoadID = nil
                    self.activeLoadTask = nil
                    self.isLoading = false
                }
            }
            do {
                let fetched = try await self.repository.fetchCaptures()
                guard self.generation == requestGeneration,
                      self.activeLoadID == requestID, !Task.isCancelled else { return }

                // Only captures acknowledged during this request need protection
                // from its older snapshot. Later requests use the server as authority.
                let fetchedIDs = Set(fetched.map(\.id))
                let newlySubmitted = self.captures.filter {
                    !knownIDs.contains($0.id) && !fetchedIDs.contains($0.id)
                }
                self.captures = (fetched + newlySubmitted).sorted {
                    ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
                }
                self.lastLoadedAt = Date()
                self.errorMessage = nil
            } catch {
                guard self.generation == requestGeneration,
                      self.activeLoadID == requestID, !Task.isCancelled else { return }
                self.handleError(error)
            }

            guard self.generation == requestGeneration,
                  self.activeLoadID == requestID, !Task.isCancelled,
                  !self.requiresSignIn else { return }
            // Fetch items even for fallback, zero-result, unchanged terminal,
            // or failed history responses. Item loading owns its own error state.
            await self.onItemsNeedsRefresh?()
        }
        activeLoadTask = task
        await task.value
    }

    func submitTextCapture(_ text: String) async throws -> Capture {
        guard !requiresSignIn else { throw APIError.unauthorized }
        guard !isSubmitting else { throw APIError.conflict }
        try Task.checkCancellation()
        let operationID = UUID()
        let requestGeneration = generation
        submissionID = operationID
        isSubmitting = true
        errorMessage = nil
        defer {
            if submissionID == operationID {
                submissionID = nil
                isSubmitting = false
            }
        }

        do {
            let created = try await repository.createCapture(text: text)
            try Task.checkCancellation()
            guard generation == requestGeneration, submissionID == operationID else {
                throw CancellationError()
            }
            captures.removeAll { $0.id == created.id }
            captures.insert(created, at: 0)
            startPollingIfNeeded()
            return created
        } catch {
            guard generation == requestGeneration, submissionID == operationID,
                  !Task.isCancelled else { throw CancellationError() }
            handleError(error)
            throw error
        }
    }

    func startPollingIfNeeded() {
        guard isForegroundActive, !requiresSignIn, hasActiveCaptures,
              pollingTask == nil, !Task.isCancelled else { return }
        let operationID = UUID()
        let requestGeneration = generation
        let wait = waitForNextPoll
        let limit = maxPollIterations
        pollingID = operationID
        pollingTask = Task { [weak self] in
            defer {
                if self?.pollingID == operationID {
                    self?.pollingID = nil
                    self?.pollingTask = nil
                }
            }
            for _ in 0..<limit {
                do { try await wait() } catch { break }
                guard let self, self.generation == requestGeneration,
                      self.pollingID == operationID, self.isForegroundActive,
                      !Task.isCancelled else { break }
                await self.loadCaptures()
                guard self.generation == requestGeneration,
                      self.pollingID == operationID, !Task.isCancelled,
                      self.hasActiveCaptures else { break }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        pollingID = nil
    }

    func reset() {
        generation += 1
        isForegroundActive = false
        stopPolling()
        cancelLoad()
        submissionID = nil
        captures = []
        isSubmitting = false
        errorMessage = nil
        lastLoadedAt = nil
        requiresSignIn = false
    }

    private func cancelLoad() {
        activeLoadTask?.cancel()
        activeLoadTask = nil
        activeLoadID = nil
        isLoading = false
    }

    private func handleError(_ error: Error) {
        if error is CancellationError { return }
        if let error = error as? APIError, error == .unauthorized || error == .forbidden {
            reset()
            requiresSignIn = true
            onSessionExpired?()
        } else {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not complete the capture request. Please try again."
        }
    }
}
