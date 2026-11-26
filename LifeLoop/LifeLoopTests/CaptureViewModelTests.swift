import Foundation
import Testing
@testable import LifeLoop

@Suite(.timeLimit(.minutes(1)))
@MainActor
struct CaptureViewModelTests {
    private func capture(_ status: CaptureProcessingStatus = .pending, id: UUID = UUID()) -> Capture {
        Capture(id: id, rawPayload: "A capture", processingStatus: status)
    }

    private func model(_ repository: ControlledCaptureRepository) -> CaptureViewModel {
        let model = CaptureViewModel(repository: repository)
        model.setForegroundActive(true)
        return model
    }

    @Test func loadRefreshesItemsEvenWhenCaptureStatusesAreUnchangedOrEmpty() async {
        let repository = ControlledCaptureRepository()
        let model = model(repository)
        var refreshes = 0
        model.onItemsNeedsRefresh = { refreshes += 1 }
        await model.loadCaptures()
        repository.captures = [capture(.completed)]
        await model.loadCaptures()
        await model.loadCaptures()
        #expect(refreshes == 3)
        #expect(model.captures == repository.captures)
    }

    @Test func captureFailurePreservesHistoryAndStillRefreshesItems() async {
        let repository = ControlledCaptureRepository()
        repository.captures = [capture(.completed)]
        let model = model(repository)
        await model.loadCaptures()
        let failure = RequestGate<[Capture]>()
        repository.fetchRequests = [failure]
        failure.resolve(.failure(APIError.server(500)))
        var itemRefreshes = 0
        model.onItemsNeedsRefresh = { itemRefreshes += 1 }
        await model.loadCaptures()
        #expect(model.captures == repository.captures)
        #expect(model.errorMessage != nil)
        #expect(itemRefreshes == 1)
        await model.loadCaptures()
        #expect(model.errorMessage == nil)
    }

    @Test func captureHistorySurvivesAnActualOrganizerFailure() async {
        let repository = ControlledCaptureRepository()
        repository.captures = [capture()]
        let model = model(repository)
        let organizer = ItemsListViewModel(repository: SampleItemRepository(items: [], shouldFail: true))
        model.onItemsNeedsRefresh = { await organizer.refreshAfterCapture() }
        await model.loadCaptures()
        guard case .failed = organizer.state else {
            Issue.record("Expected the Organizer request to fail")
            return
        }
        #expect(model.captures.count == 1)
        #expect(model.errorMessage == nil)
    }

    @Test func overlappingLoadsShareReconciliationAndItemRefresh() async {
        let repository = ControlledCaptureRepository()
        let response = RequestGate<[Capture]>()
        repository.fetchRequests = [response]
        let model = model(repository)
        var refreshes = 0
        model.onItemsNeedsRefresh = { refreshes += 1 }
        let first = Task { await model.loadCaptures() }
        await response.waitUntilStarted()
        let joined = RequestGate<Void>()
        let second = Task {
            joined.resolve(.success(()))
            await model.loadCaptures()
        }
        try? await joined.value()
        #expect(repository.fetchCount == 1)
        response.resolve(.success([capture(.completed)]))
        await first.value
        await second.value
        #expect(refreshes == 1)
        #expect(model.captures.count == 1)
        #expect(!model.isLoading)
    }

    @Test func staleSnapshotPreservesConcurrentSubmissionButFreshSnapshotRemovesWebDeletion() async throws {
        let repository = ControlledCaptureRepository()
        let old = capture(.completed)
        repository.captures = [old]
        let model = model(repository)
        await model.loadCaptures()
        let response = RequestGate<[Capture]>()
        repository.fetchRequests = [response]
        let load = Task { await model.loadCaptures() }
        await response.waitUntilStarted()
        let created = try await model.submitTextCapture("New text")
        model.stopPolling()
        response.resolve(.success([old]))
        await load.value
        #expect(Set(model.captures.map(\.id)) == [old.id, created.id])
        // A later server snapshot is authoritative, including deletion on web.
        repository.captures = []
        await model.loadCaptures()
        #expect(model.captures.isEmpty)
    }

    @Test func resetRejectsOldLoadAndOldCleanupCannotClearNewLoad() async {
        let repository = ControlledCaptureRepository()
        let oldResponse = RequestGate<[Capture]>()
        let newResponse = RequestGate<[Capture]>()
        repository.fetchRequests = [oldResponse, newResponse]
        let model = model(repository)
        let oldLoad = Task { await model.loadCaptures() }
        await oldResponse.waitUntilStarted()
        model.reset()
        model.setForegroundActive(true)
        let newLoad = Task { await model.loadCaptures() }
        await newResponse.waitUntilStarted()
        oldResponse.resolve(.success([capture(.completed)]))
        await oldLoad.value
        #expect(model.captures.isEmpty)
        #expect(model.isLoading)
        let current = capture(.completed)
        newResponse.resolve(.success([current]))
        await newLoad.value
        #expect(model.captures == [current])
        #expect(!model.isLoading)
    }

    @Test func oldSubmissionThrowsCancellationAndCannotEnableDuplicatePOST() async throws {
        let repository = ControlledCaptureRepository()
        let oldResponse = RequestGate<Capture>()
        let newResponse = RequestGate<Capture>()
        repository.createRequests = [oldResponse, newResponse]
        let model = model(repository)
        let oldSubmit = Task { try await model.submitTextCapture("Old account") }
        await oldResponse.waitUntilStarted()
        model.reset()
        model.setForegroundActive(true)
        let newSubmit = Task { try await model.submitTextCapture("Current account") }
        await newResponse.waitUntilStarted()
        oldResponse.resolve(.success(capture()))
        await #expect(throws: CancellationError.self) { try await oldSubmit.value }
        #expect(model.isSubmitting)
        await #expect(throws: APIError.conflict) {
            try await model.submitTextCapture("Duplicate")
        }
        #expect(repository.createCount == 2)
        let created = capture()
        newResponse.resolve(.success(created))
        _ = try await newSubmit.value
        #expect(model.captures == [created])
        #expect(!model.isSubmitting)
        model.stopPolling()
    }

    @Test func cancelledSubmissionCannotReturnSuccess() async {
        let repository = ControlledCaptureRepository()
        let response = RequestGate<Capture>()
        repository.createRequests = [response]
        let model = model(repository)
        let submit = Task { try await model.submitTextCapture("Cancelled") }
        await response.waitUntilStarted()
        submit.cancel()
        response.resolve(.success(capture()))
        await #expect(throws: CancellationError.self) { try await submit.value }
        #expect(model.captures.isEmpty)
        #expect(!model.isSubmitting)
    }

    @Test func foregroundSuspensionRejectsDelayedRefreshAndPreventsRestart() async {
        let repository = ControlledCaptureRepository()
        repository.captures = [capture()]
        let model = model(repository)
        await model.loadCaptures()
        let response = RequestGate<[Capture]>()
        repository.fetchRequests = [response]
        let load = Task {
            await model.loadCaptures()
            model.startPollingIfNeeded()
        }
        await response.waitUntilStarted()
        model.setForegroundActive(false)
        response.resolve(.success([capture(.completed)]))
        await load.value
        #expect(model.captures == repository.captures)
        #expect(!model.isLoading)
        // Foreground entry always fetches again, including terminal captures.
        repository.captures = [capture(.completed)]
        model.setForegroundActive(true)
        await model.loadCaptures()
        #expect(model.captures == repository.captures)
    }

    @Test func pollAndManualLoadShareOneFetch() async {
        let repository = ControlledCaptureRepository()
        repository.captures = [capture()]
        let tick = RequestGate<Void>()
        let model = CaptureViewModel(repository: repository, maxPollIterations: 1) {
            try await tick.value()
        }
        model.setForegroundActive(true)
        await model.loadCaptures()
        let response = RequestGate<[Capture]>()
        repository.fetchRequests = [response]
        model.startPollingIfNeeded()
        await tick.waitUntilStarted()
        tick.resolve(.success(()))
        await response.waitUntilStarted()
        let joined = RequestGate<Void>()
        let manual = Task {
            joined.resolve(.success(()))
            await model.loadCaptures()
        }
        try? await joined.value()
        #expect(repository.fetchCount == 2) // Initial history + shared request.
        response.resolve(.success([capture(.completed)]))
        await manual.value
        #expect(model.captures.first?.processingStatus == .completed)
        model.stopPolling()
    }

    @Test func boundedPollingRefreshesFallbackAndCompletionAndManualRefreshStillWorks() async {
        let repository = ControlledCaptureRepository()
        let id = UUID()
        repository.captures = [capture(.pending, id: id)]
        let firstTick = RequestGate<Void>()
        let secondTick = RequestGate<Void>()
        let firstResponse = RequestGate<[Capture]>()
        let secondResponse = RequestGate<[Capture]>()
        var waits = 0
        let model = CaptureViewModel(repository: repository, maxPollIterations: 2) {
            waits += 1
            if waits == 1 { try await firstTick.value() }
            else { try await secondTick.value() }
        }
        model.setForegroundActive(true)
        await model.loadCaptures()
        repository.fetchRequests = [firstResponse, secondResponse]
        var refreshedStatuses: [CaptureProcessingStatus] = []
        let completionObserved = RequestGate<Void>()
        model.onItemsNeedsRefresh = { [weak model] in
            if let status = model?.captures.first?.processingStatus {
                refreshedStatuses.append(status)
                if status == .completed { completionObserved.resolve(.success(())) }
            }
        }
        model.startPollingIfNeeded()
        await firstTick.waitUntilStarted()
        firstTick.resolve(.success(()))
        await firstResponse.waitUntilStarted()
        firstResponse.resolve(.success([capture(.fallbackPendingRetry, id: id)]))
        await secondTick.waitUntilStarted()
        #expect(refreshedStatuses == [.fallbackPendingRetry])
        secondTick.resolve(.success(()))
        await secondResponse.waitUntilStarted()
        secondResponse.resolve(.success([capture(.completed, id: id)]))
        try? await completionObserved.value()
        #expect(refreshedStatuses == [.fallbackPendingRetry, .completed])
        #expect(waits == 2)
        model.stopPolling()
        repository.captures = []
        await model.loadCaptures()
        #expect(model.captures.isEmpty)
    }

    @Test func oldPollingTaskCannotClearReplacementAfterSuspendedItemRefresh() async {
        let repository = ControlledCaptureRepository()
        repository.captures = [capture()]
        let oldTick = RequestGate<Void>()
        let newTick = RequestGate<Void>()
        var waits = 0
        let model = CaptureViewModel(repository: repository, maxPollIterations: 1) {
            waits += 1
            if waits == 1 { try await oldTick.value() }
            else { try await newTick.value() }
        }
        model.setForegroundActive(true)
        await model.loadCaptures()
        let itemRefresh = RequestGate<Void>()
        model.onItemsNeedsRefresh = { try? await itemRefresh.value() }
        model.startPollingIfNeeded()
        await oldTick.waitUntilStarted()
        oldTick.resolve(.success(()))
        await itemRefresh.waitUntilStarted()
        model.setForegroundActive(false)
        model.setForegroundActive(true)
        model.startPollingIfNeeded()
        await newTick.waitUntilStarted()
        itemRefresh.resolve(.success(()))
        // The replacement has its own identity and can still complete.
        newTick.resolve(.success(()))
        await model.loadCaptures()
        #expect(waits == 2)
        #expect(model.captures == repository.captures)
        model.stopPolling()
    }

    @Test func authenticationFailureInvalidatesStateAndNotifiesOnce() async {
        let repository = ControlledCaptureRepository()
        repository.captures = [capture()]
        let model = model(repository)
        await model.loadCaptures()
        let response = RequestGate<[Capture]>()
        response.resolve(.failure(APIError.unauthorized))
        repository.fetchRequests = [response]
        var notifications = 0
        model.onSessionExpired = { notifications += 1 }
        await model.loadCaptures()
        #expect(model.requiresSignIn)
        #expect(model.captures.isEmpty)
        #expect(notifications == 1)
        let requests = repository.fetchCount
        model.startPollingIfNeeded()
        await model.loadCaptures()
        #expect(repository.fetchCount == requests)
        #expect(notifications == 1)
    }

    @Test func failedSubmissionCanBeRetriedWithoutAutomaticPOST() async throws {
        let repository = ControlledCaptureRepository()
        let failure = RequestGate<Capture>()
        failure.resolve(.failure(APIError.server(500)))
        repository.createRequests = [failure]
        let model = model(repository)
        await #expect(throws: APIError.server(500)) {
            try await model.submitTextCapture("Keep this text")
        }
        #expect(repository.createCount == 1)
        #expect(model.errorMessage != nil)
        #expect(!model.isSubmitting)
        let created = try await model.submitTextCapture("Keep this text")
        #expect(repository.createCount == 2)
        #expect(created.rawPayload == "Keep this text")
        #expect(model.errorMessage == nil)
        model.stopPolling()
    }
}

/// Deliberately ignores cancellation so tests can release stale responses in any order.
@MainActor
private final class RequestGate<Value: Sendable> {
    private var result: Result<Value, Error>?
    private var continuation: CheckedContinuation<Value, Error>?
    private var started = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    func value() async throws -> Value {
        started = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()
        if let result { return try result.get() }
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func resolve(_ result: Result<Value, Error>) {
        self.result = result
        continuation?.resume(with: result)
        continuation = nil
    }
}

@MainActor
private final class ControlledCaptureRepository: CaptureRepository {
    var captures: [Capture] = []
    var fetchRequests: [RequestGate<[Capture]>] = []
    var createRequests: [RequestGate<Capture>] = []
    private(set) var fetchCount = 0
    private(set) var createCount = 0

    func fetchCaptures() async throws -> [Capture] {
        fetchCount += 1
        if !fetchRequests.isEmpty { return try await fetchRequests.removeFirst().value() }
        return captures
    }

    func createCapture(text: String, source: String) async throws -> Capture {
        createCount += 1
        if !createRequests.isEmpty { return try await createRequests.removeFirst().value() }
        let created = Capture(id: UUID(), source: source, rawPayload: text)
        captures.insert(created, at: 0)
        return created
    }
}
