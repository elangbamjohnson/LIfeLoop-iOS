# LifeLoop iOS — Technology Stack and Learning Guide

This document records the architecture, technology stack, and implementation patterns established in the LifeLoop iOS codebase, with a focus on Phase 2: connected, revision-aware title editing and cache reconciliation.

---

## 1. Architectural Foundation & Overview

LifeLoop iOS is architected using **Clean Architecture** principles layered with **MVVM** and **Unidirectional Data Flow**:

```
┌────────────────────────────────────────────────────────┐
│                   Presentation Layer                   │
│   SwiftUI Views (RootView, ItemDetailView, EditView)   │
│   Observable ViewModels (ItemsListViewModel)           │
└───────────────────────────┬────────────────────────────┘
                            │ depends on
                            ▼
┌────────────────────────────────────────────────────────┐
│                      Domain Layer                      │
│   Entities (LifeItem, ItemStatus, JSONValue)           │
│   Capabilities & Errors (OrganizerCapabilities,        │
│                          ItemMutationError)            │
│   Repository Protocols (ItemRepository)                │
└───────────────────────────▲────────────────────────────┘
                            │ implemented by
┌───────────────────────────┴────────────────────────────┘
│                   Data & Persistence                   │
│   API Repositories (APIItemRepository)                 │
│   Caching Adapters (CachedItemRepository)              │
│   Local Store (AccountLocalStore with SwiftData)       │
│   Networking (APIClient, HTTPTransport, DTOs)          │
└────────────────────────────────────────────────────────┘
```

### Dependency Inversion & Isolation Invariants
1. **Domain Isolation**: Domain entities, errors (`ItemMutationError`), and capabilities (`OrganizerCapabilities`) have zero dependencies on SwiftUI, SwiftData, or URLSession networking.
2. **Inward Dependencies**: Presentation depends only on Domain protocols. ViewModels do not reference concrete Data classes like `APIItemRepository` or HTTP status codes.
3. **Account Scoping**: All persistence in `AccountLocalStore` is keyed by `scope = server|accountID`. Session sign-out triggers `purgeAndInvalidate()`, preventing data leakage across accounts.

---

## 2. Core Technologies Explained

### 1. SwiftUI State Management & Safe Draft Lifecycle
- **What it does**: Drives the declarative user interface using `@State`, `@Binding`, `@Environment`, and modal presentations (`.fullScreenCover`).
- **Why LifeLoop uses it**: Provides smooth reactive rendering across iPhone and iPad while isolating view-local state from external parent re-renders.
- **Key implementation in Title Editing**:
  - In `ItemEditView`, active text is bound to `@State private var draftTitle: String`.
  - When the editor opens, the item's integer revision is captured in `@State private var baseRevision: Int?`.
  - In SwiftUI, `@State` properties are initialized once when the view mounts. If a background sync or list reload updates `RootView`'s body, SwiftUI retains the mounted `@State` values. This guarantees that `baseRevision` never silently advances in the background while the user is typing.
  - If a concurrent change occurs or a revision is missing, an explicit "Reload latest item" action allows fetching the new base revision without discarding the user's typed draft.
- **Important files**:
  - `LifeLoop/Features/Organizer/Presentation/ItemEditView.swift`
  - `LifeLoop/App/RootView.swift`
  - `LifeLoop/Features/Organizer/Presentation/ItemDetailView.swift`

### 2. MVVM & Dependency Injection
- **What it does**: Isolates UI state and business logic into an observable view model (`ItemsListViewModel`), injected with abstract dependencies via initializers.
- **Why LifeLoop uses it**: Enables deterministic unit testing of UI logic without spinning up simulator views, network connections, or file storage.
- **Key implementation**:
  - `ItemsListViewModel` conforms to `@Observable` and is `@MainActor`-isolated.
  - Receives `repository: any ItemRepository` in its initializer.
  - Tracks loading state (`.idle`, `.loading`, `.loaded([LifeItem])`, `.empty`, `.failed(String)`), active mutations (`mutatingItemIDs: Set<UUID>`), and authentication flags (`requiresSignIn: Bool`).
  - Guards missing or non-positive revisions before invoking the repository, throwing `ItemMutationError.invalidRevision`.
- **Important files**:
  - `LifeLoop/Features/Organizer/Presentation/ItemsListViewModel.swift`
  - `LifeLoop/LifeLoopTests/ItemsListViewModelTests.swift`

### 3. Repository Protocols & Dependency Inversion
- **What it does**: Defines data-access contracts in the Domain layer (`ItemRepository`) implemented by concrete adapters in the Data layer (`CachedItemRepository`, `APIItemRepository`, `SampleItemRepository`).
- **Why LifeLoop uses it**: Separates presentation logic from transport mechanisms. SwiftUI previews and tests run instantly with `SampleItemRepository` or stubs, while production uses `CachedItemRepository` wrapping `APIItemRepository`.
- **Key implementation**:
  - `func updateItem(id: UUID, title: String, expectedRevision: Int) async throws -> LifeItem`
  - `OrganizerCapabilities` encapsulates fine-grained action permissions (`allowsTitleEditing: Bool`, `allowsItemMutations: Bool`). Connected users run with `.titleOnly`, which enables title edits while keeping `completeItem`, `reopenItem`, `deleteItem`, and `createItem` strictly disabled.
- **Important files**:
  - `LifeLoop/Features/Organizer/Domain/ItemRepository.swift`
  - `LifeLoop/Features/Account/Presentation/ConnectedOrganizerView.swift`

### 4. URLSession & Revision-Aware PATCH Operation
- **What it does**: Handles HTTP communication with the LifeLoop Express/Postgres backend using modern Swift async/await and `URLSession`.
- **Why LifeLoop uses it**: Sends lightweight, atomic mutation payloads with cookie-based session authentication.
- **Key implementation**:
  - The title PATCH request to `api/v1/items/:id` serializes `UpdateItemTitleRequest`, sending **only** `title: String` and `expectedRevision: Int`. Timestamps, metadata, statuses, and due dates are omitted to prevent accidental metadata overwrites.
  - Validates the returned canonical `ItemDTO`, checking ID consistency and strict revision advancement (`canonicalRevision > expectedRevision`).
  - Disables blind retries on network failures or conflict responses to protect against race conditions.
- **Important files**:
  - `LifeLoop/Features/Organizer/Data/APIItemRepository.swift`
  - `LifeLoop/Features/Organizer/Data/ItemMutationDTO.swift`
  - `LifeLoop/App/Networking/APIClient.swift`

### 5. SwiftData Cache Reconciliation
- **What it does**: Manages on-device persistent storage using Apple's SwiftData framework (`ModelContainer`, `ModelContext`, `LocalRecord`).
- **Why LifeLoop uses it**: Provides offline read resilience and persists uncommitted draft titles across app launches.
- **Key implementation**:
  - `AccountLocalStore` manages `LocalRecord` entities scoped by `server|accountID`.
  - `ItemDraft` stores both legacy string timestamps (`baseRevision: String?`) and integer revisions (`baseItemRevision: Int?`) without reinterpreting legacy data.
  - When `CachedItemRepository.updateItem` receives a successful remote response, it immediately invokes `store.updateItem(updated)`. This reconciles the cached snapshot in SwiftData so subsequent offline loads or app restarts reflect the canonical title and revision rather than reverting to stale data.
- **Important files**:
  - `LifeLoop/Features/Organizer/Persistence/AccountLocalStore.swift`
  - `LifeLoop/Features/Organizer/Data/CachedItemRepository.swift`
  - `LifeLoop/LifeLoopTests/CachedItemRepositoryTests.swift`

### 6. Optimistic Concurrency & HTTP 409 Conflict Handling
- **What it does**: Prevents lost updates when multiple devices or web sessions edit the same item concurrently.
- **Why LifeLoop uses it**: Timestamps (`updatedAt`) suffer from clock skew, sub-millisecond truncation, and race conditions. An integer revision (`expectedRevision`) provides deterministic serializability.
- **Key implementation**:
  - If another client increments the database revision to `5`, a request sent with `expectedRevision: 4` is atomically rejected by the PostgreSQL transaction with HTTP 409 (`REVISION_CONFLICT`).
  - `APIItemRepository` maps `APIError.conflict` to domain `ItemMutationError.conflict`.
  - `ItemEditView` preserves the user's uncommitted draft, displays a non-destructive conflict explanation, and provides an option to reload the latest server item to inspect the new base revision before deciding to overwrite or discard.
- **Important files**:
  - `LifeLoop/Features/Organizer/Data/APIItemRepository.swift`
  - `LifeLoop/Features/Organizer/Presentation/ItemEditView.swift`
  - `LifeLoop/LifeLoopTests/APIContractTests.swift`

---

## 3. Test Verification Strategy

LifeLoop tests are implemented using the modern **Swift Testing** framework (`import Testing`):
1. **API Contract Tests (`APIContractTests.swift`)**:
   - Verify JSON encoding of `UpdateItemTitleRequest` contains only `title` and `expectedRevision`.
   - Verify HTTP 409 translates to `ItemMutationError.conflict` without automatic retry loops.
   - Verify invalid revisions ($\le 0$) fail before any network request is initiated.
   - Verify unversioned responses and non-advancing revisions throw `APIError.invalidResponse`.
2. **Cache Reconciliation Tests (`CachedItemRepositoryTests.swift`)**:
   - Verify `updateItem` updates `AccountLocalStore`.
   - Verify offline fallback (`URLError.notConnectedToInternet`) serves the reconciled title and revision.
   - Verify account isolation and draft purging.
3. **ViewModel Tests (`ItemsListViewModelTests.swift`)**:
   - Verify `saveTitle` updates ViewModel state and propagates canonical server models.
   - Verify missing revisions are guarded and throw `ItemMutationError.invalidRevision`.
4. **UI Tests (`OrganizerUITests.swift`)**:
   - Verify accessibility audits pass on the large text editor (`performAccessibilityAudit`).
   - Verify draft retention across orientation rotation and cancellation flows.

---

## 4. Phase 3 & Feature 1.1 Technical Deep Dive & Key Learnings

Feature 1.1 expands LifeLoop from connected title-editing into a full-featured actionable organizer: complete, reopen, snooze, delete, and confirm review actions, supported by derived priority/timeline grouping, a responsive carousel UI, resilient date parsing, and local cache reconciliation.

### 1. PriorityGrouping and TimelineGrouping
- **Why it was used**:
  - The web application organizes items dynamically into operational urgency buckets (`Reminders & Due Today`, `Needs Attention`, `Today`, `Tomorrow`, `This Week`, `Upcoming`, `Waiting For`, and `Past/History`).
  - Instead of requiring multiple specialized backend endpoints or complex server SQL queries, the native client fetches the canonical item collection and computes these groupings deterministically on device.
  - Crucially, items must not duplicate across sections: an item due today that has `pending_review` status belongs in `Needs Attention` (and the top carousel), but must be deduplicated out of `Today` and `Upcoming` to avoid redundant cards.
- **How it works**:
  - `TimelineGrouping` is an immutable, pure value type.
  - **Target Date Resolution**: Checks `item.snoozedUntil` first (a snoozed item's deferral supersedes its original due date), followed by `item.dueDate`, then fallback metadata keys `"dueDate"` and `"expiryDate"` via `LifeItem.parseDate`.
  - **Bucketing Rules**:
    - Completed items are routed immediately to `past`.
    - Delegated tasks (`item.waitingForPerson != nil` or `itemType == "waiting_for"`) route to `waitingFor` (unless `pendingReview`).
    - Items without target dates default to `upcoming` (or `needsAttention` if `pendingReview`).
    - Items with target dates compute day difference from `calendar.startOfDay(for: referenceDate)` to `calendar.startOfDay(for: target)`:
      - Overdue ($days < 0$ or same day with passed timestamp) $\to$ `needsAttention`.
      - $days == 0 \to$ `today`.
      - $days == 1 \to$ `tomorrow`.
      - $days \le 7 \to$ `thisWeek`.
      - $days > 7 \to$ `upcoming`.
    - Non-overdue `pendingReview` items are also appended to `needsAttention`.
    - Every bucket is sorted chronologically by target date, using title as a deterministic tie-breaker.
  - `PriorityGrouping` adapts `TimelineGrouping`:
    - `carouselItems = timeline.needsAttention + self.today`
    - `today = timeline.today.filter { $0.status != .pendingReview }`
    - `upcoming = (timeline.tomorrow + timeline.thisWeek + timeline.upcoming).filter { $0.status != .pendingReview }`
- **Key files**:
  - `LifeLoop/Features/Organizer/Domain/TimelineGrouping.swift`
  - `LifeLoop/Features/Organizer/Domain/PriorityGrouping.swift`
  - `LifeLoop/LifeLoopTests/TimelineGroupingTests.swift`
  - `LifeLoop/LifeLoopTests/PriorityGroupingTests.swift`
- **Swift code example**:
```swift
struct PriorityGrouping: Equatable {
    let carouselItems: [LifeItem]
    let needsAttention: [LifeItem]
    let today: [LifeItem]
    let upcoming: [LifeItem]
    let waitingFor: [LifeItem]

    init(from timeline: TimelineGrouping) {
        self.needsAttention = timeline.needsAttention
        // Deduplicate: pendingReview items stay in needsAttention only
        self.today = timeline.today.filter { $0.status != .pendingReview }
        self.upcoming = (timeline.tomorrow + timeline.thisWeek + timeline.upcoming)
            .filter { $0.status != .pendingReview }
        self.waitingFor = timeline.waitingFor
        self.carouselItems = timeline.needsAttention + self.today
    }
}
```

---

### 2. SwiftUI Carousel Architecture
- **Why it was used**:
  - Users need instant, glanceable visibility into urgent items (`needsAttention`) and tasks due today without scrolling through long list views.
  - The carousel allows direct execution of primary actions (Done, Snooze +1d, Edit, Confirm) directly from the cards.
  - Expandable row items below the carousel need polished animations so that disclosure views (such as Waiting-For follow-up controls) do not cause jarring layout jumps.
- **How it works**:
  - `PriorityCarouselView` pairs `ScrollView(.horizontal, showsIndicators: false)` with `LazyHStack(spacing: 12)`.
  - `LazyHStack` ensures cards are only instantiated and laid out as they scroll into the viewport, maintaining high rendering performance.
  - Each `PriorityCarouselCard` uses a fixed frame of `width: 270, height: 135` with continuous rounded corners (`14pt`), a 0.5pt subtle border, and integrated bottom action bar.
  - In `ItemRowView`, expanding and collapsing details uses SwiftUI's `.transition(.asymmetric(...))`:
    - **Insertion**: `.opacity.animation(.easeInOut(duration: 0.2).delay(0.06))` — slight delay gives the card container time to expand before text fades in, preventing text clipping.
    - **Removal**: `.opacity.animation(.easeInOut(duration: 0.14))` — content quickly fades out before the container height snaps shut.
- **Key files**:
  - `LifeLoop/Features/Organizer/Presentation/Priority/PriorityCarouselView.swift`
  - `LifeLoop/Features/Organizer/Presentation/Priority/PriorityCarouselCard.swift`
  - `LifeLoop/Features/Organizer/Presentation/ItemRowView.swift`
- **Swift code example**:
```swift
// Carousel with horizontal scroll and lazy stack
ScrollView(.horizontal, showsIndicators: false) {
    LazyHStack(spacing: 12) {
        ForEach(items) { item in
            PriorityCarouselCard(
                item: item,
                isMutating: mutatingItemIDs.contains(item.id),
                onComplete: { onComplete(item) },
                onSnooze: { onSnooze(item) },
                onEdit: { onEdit(item) },
                onConfirmReview: item.status == .pendingReview ? { onConfirmReview?(item) } : nil
            )
        }
    }
    .padding(.horizontal, 4)
}

// Asymmetric transition for card expansion in ItemRowView
if isExpanded {
    VStack(alignment: .leading, spacing: 10) {
        // Expanded details & Waiting For action bar
    }
    .transition(.asymmetric(
        insertion: .opacity.animation(.easeInOut(duration: 0.2).delay(0.06)),
        removal: .opacity.animation(.easeInOut(duration: 0.14))
    ))
    .clipped()
}
```

---

### 3. Codable and the `JSONValue.null` Optional Trap
- **Why it was used**:
  - LifeLoop stores arbitrary metadata from AI extraction and user fields in `metadata: [String: JSONValue]`.
  - When decoding JSON where `"waitingFor": null`, the decoder produces `JSONValue.null`.
  - In Swift, dictionary subscripting returns an optional: `metadata["waitingFor"] -> Optional<JSONValue>`.
  - If a developer checks `if metadata["waitingFor"] != nil`, this checks whether the key exists in the dictionary. Because the value is `.null`, the subscript returns `Optional.some(JSONValue.null)`.
  - In Swift, `Optional.some(...) != .none` evaluates to **`true`**! This causes the item to be misclassified as an active Waiting For item even when the server explicitly set the field to `null`.
- **How it works**:
  - The fix introduces a safe domain computed property `item.waitingForPerson: String?`.
  - It uses Swift pattern matching (`if case .string(let person) = metadata["waitingFor"]`) combined with whitespace trimming and non-emptiness checks.
  - If the metadata value is `.null`, `.number`, `.bool`, or an empty string, pattern matching fails gracefully and returns `nil`.
- **Key files**:
  - `LifeLoop/Features/Organizer/Domain/JSONValue.swift`
  - `LifeLoop/Features/Organizer/Domain/LifeItem.swift`
  - `LifeLoop/Features/Organizer/Domain/TimelineGrouping.swift`
- **Swift code example**:
```swift
// ⚠️ THE TRAP:
let metadata: [String: JSONValue] = ["waitingFor": .null]
if metadata["waitingFor"] != nil {
    // Evaluates to TRUE! Optional.some(JSONValue.null) != nil.
}

// ✅ THE FIX PATTERN (LifeItem.swift):
var waitingForPerson: String? {
    let candidateKeys = ["waitingFor", "person", "waitingOn"]
    for key in candidateKeys {
        if case .string(let person) = metadata[key] {
            let trimmed = person.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
    }
    return nil // JSONValue.null and empty strings safely return nil
}

// Clean usage in TimelineGrouping.swift:
let isWaitingFor = item.itemType.lowercased() == "waiting_for"
    || item.waitingForPerson != nil
    || item.metadata["isWaitingFor"] == .bool(true)
```

---

### 4. Resilient Date Parsing (`LifeItem.parseDate`)
- **Why it was used**:
  - Backend endpoints, database columns, and third-party AI extractions produce date representations in diverse formats: ISO8601 with fractional seconds (`2026-11-18T10:00:00.000Z`), ISO8601 without fractional seconds (`2026-11-18T10:00:00Z`), date-only strings (`2026-11-25`), and legacy localized formats.
  - A rigid single-format parser silently fails on non-conforming items, causing due dates to be dropped and overdue warnings to be missed.
- **How it works**:
  - `LifeItem.parseDate` executes a fast-to-slow fallback chain:
    1. First tries `ISO8601DateFormatter` with `[.withInternetDateTime, .withFractionalSeconds]`.
    2. Then tries `ISO8601DateFormatter` with `[.withInternetDateTime]`.
    3. Falls back to a reusable `DateFormatter` locked to `Locale(identifier: "en_US_POSIX")` to ensure format string tokens are not overridden by the user's regional calendar settings.
    4. Evaluates an 8-format fallback list:
       - `yyyy-MM-dd'T'HH:mm:ss.SSSZ`
       - `yyyy-MM-dd'T'HH:mm:ss.SSS`
       - `yyyy-MM-dd'T'HH:mm:ssZ`
       - `yyyy-MM-dd'T'HH:mm:ss`
       - `yyyy-MM-dd HH:mm:ss`
       - `yyyy-MM-dd`
       - `dd MMM yyyy`
       - `MM/dd/yyyy`
  - **Timezone Semantics**:
    - Timestamps with timezone offsets (`Z` or `±HH:mm`) resolve deterministically to UTC.
    - Plain date strings (`yyyy-MM-dd`) currently apply `TimeZone.current`, resolving midnight in device-local time. (Noted in the deferred backlog for UTC normalization).
- **Key files**:
  - `LifeLoop/Features/Organizer/Domain/LifeItem.swift`
  - `LifeLoop/LifeLoopTests/TimelineGroupingTests.swift`
- **Swift code example**:
```swift
extension LifeItem {
    static func parseDate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: trimmed) { return date }

        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: trimmed) { return date }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ssZ",    "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",       "yyyy-MM-dd",
            "dd MMM yyyy",               "MM/dd/yyyy"
        ]
        for format in formats {
            df.dateFormat = format
            if let date = df.date(from: trimmed) { return date }
        }
        return nil
    }
}
```

---

### 5. State-Driven Mutation Actions and Cache Reconciliation
- **Why it was used**:
  - Mobile networks are prone to dropped packets, airplane mode toggles, and server error responses.
  - Blindly applying optimistic local changes risks UI desynchronization when a server rejects a write (e.g. 409 conflict or 401 unauthorized).
  - LifeLoop uses **server-confirmed mutations**: the UI waits for the authoritative server response before committing the change locally, while immediately providing visual loading indicators and disabling duplicate submissions.
- **How it works**:
  - `ItemsListViewModel` maintains `mutatingItemIDs: Set<UUID>`.
  - When an action begins, `mutatingItemIDs.insert(item.id)` disables further button interactions on that card/row and displays a spinner.
  - A Swift `defer { mutatingItemIDs.remove(item.id) }` guarantees that the mutating lock is always cleared upon exit, even when errors are thrown or tasks cancelled.
  - When the server returns the updated `LifeItem`, `CachedItemRepository` immediately reconciles the persistent SwiftData store:
    - **For mutations (`complete`, `reopen`, `snooze`, `confirmReview`)**: `try? store.updateItem(updated)` updates the item in the cached snapshot.
    - **For deletion (`deleteItem`)**: `try? store.deleteItem(id: id)` filters out the deleted item from the local snapshot.
  - This eliminates the critical bug where deleted items resurfaced from SwiftData on an offline cold launch.
- **Key files**:
  - `LifeLoop/Features/Organizer/Presentation/ItemsListViewModel.swift`
  - `LifeLoop/Features/Organizer/Data/CachedItemRepository.swift`
  - `LifeLoop/Features/Organizer/Persistence/AccountLocalStore.swift`
- **Swift code example**:
```swift
// ItemsListViewModel: Protected execution with defer cleanup
func completeItem(_ item: LifeItem) async {
    guard case .loaded = state, !mutatingItemIDs.contains(item.id) else { return }
    mutatingItemIDs.insert(item.id)
    defer { mutatingItemIDs.remove(item.id) }

    do {
        let updated = try await repository.completeItem(id: item.id, updatedAt: item.updatedAt)
        updateItem(updated) // Replaces item in ViewModel memory
    } catch {
        actionError = (error as? APIError)?.errorDescription ?? "Could not complete this item."
    }
}

// CachedItemRepository: Remote call + SwiftData store update
func completeItem(id: UUID, updatedAt: String?) async throws -> LifeItem {
    let updated = try await remote.completeItem(id: id, updatedAt: updatedAt)
    try? store.updateItem(updated)
    return updated
}

// AccountLocalStore: Deletion reconciliation
func deleteItem(id: UUID) throws {
    guard let snapshot = try readItems() else { return }
    var items = snapshot.items
    let originalCount = items.count
    items.removeAll(where: { $0.id == id })
    if items.count != originalCount {
        try write(items, name: "items")
    }
}
```

---

### 6. Feature Capability Gating and UI Protection
- **Why it was used**:
  - Exposing UI controls before their backing endpoints or domain handlers are production-ready creates user confusion, failed operations, and data integrity hazards.
  - In F1.1, connected users could see a floating `+` button (Quick Capture). Tapping it presented `ItemEditView` as a creation form, but saving an unpersisted item invariably failed with `"This item has no valid revision to save"` because item creation (`POST /api/v1/items`) belongs to F1.2.
  - Rather than deleting future creation code, the application uses **feature capability gating** to cleanly hide the control until F1.2 while keeping the underlying implementation ready.
- **How it works**:
  - `OrganizerCapabilities` encapsulates discrete permission flags (`allowsTitleEditing`, `allowsItemMutations`, `allowsItemCreation`, and `isDemo`).
  - Standard presets (`none`, `titleOnly`, `connected`, and `demo`) initialize `allowsItemCreation = false` for F1.1.
  - In `ItemsListView`, the floating action button overlay is guarded by `if capabilities.allowsItemCreation`.
  - When F1.2 is scheduled, enabling item creation requires only flipping `allowsItemCreation = true` in connected capabilities and wiring the `createItem` endpoint.
- **Key files**:
  - `LifeLoop/Features/Organizer/Domain/ItemRepository.swift`
  - `LifeLoop/Features/Organizer/Presentation/ItemsListView.swift`
  - `LifeLoop/LifeLoopTests/APIContractTests.swift`
  - `LifeLoop/LifeLoopUITests/OrganizerUITests.swift`
- **Swift code example**:
```swift
// LifeLoop/Features/Organizer/Domain/ItemRepository.swift
struct OrganizerCapabilities: Equatable {
    var allowsTitleEditing: Bool
    var allowsItemMutations: Bool
    var allowsItemCreation: Bool
    var isDemo: Bool

    static let connected = OrganizerCapabilities(
        allowsTitleEditing: true,
        allowsItemMutations: true,
        allowsItemCreation: false,
        isDemo: false
    )
}

// LifeLoop/Features/Organizer/Presentation/ItemsListView.swift
.overlay(alignment: .bottomTrailing) {
    if capabilities.allowsItemCreation {
        Button {
            let newItem = LifeItem(id: UUID(), title: "", status: .active)
            onEditItem?(newItem)
        } label: {
            Image(systemName: "plus")
                .frame(width: 52, height: 52)
                .background(Color(uiColor: .label), in: Circle())
        }
        .accessibilityIdentifier("quickCaptureButton")
    }
}
```

---

### 7. Optimistic Concurrency and Conflict Handling in Review Confirmation
- **Why it was used**:
  - AI-assisted item confirmation (`confirmReviewItem`) transitions items from `.pendingReview` to `.active` via `PATCH /api/v1/items/:id`.
  - If a user confirms an item that was concurrently modified in a web session (e.g. title corrected, due date rescheduled), blind status updates could overwrite newer server data.
  - Enforcing optimistic concurrency with `expectedRevision` guarantees the update only applies if the server-side state matches the client's snapshot.
- **How it works**:
  - `ConfirmReviewRequest` encodes `{ "status": "active", "expectedRevision": Int }`. The revision is non-optional.
  - Before making network requests, `ItemsListViewModel` and `APIItemRepository` validate that `expectedRevision > 0`. If missing or invalid, an `ItemMutationError.invalidRevision` error is raised immediately.
  - The server checks `existingItem.revision === expectedRevision` atomically under a database row lock.
  - If a conflict occurs, the server responds with HTTP 409 Conflict (`REVISION_CONFLICT`).
  - `APIClient` throws `APIError.conflict`, which `APIItemRepository` translates to `ItemMutationError.conflict`.
  - The ViewModel presents a localized warning ("This item has changed on the server. Please refresh before trying again.") and halts mutation without blind retries or overwriting server state.
  - On 200 OK, the repository asserts `canonicalRevision > expectedRevision`, decodes the canonical entity, and synchronizes the local cache (`try? store.updateItem(updated)`).
- **Key files**:
  - `LifeLoop/Features/Organizer/Data/ItemMutationDTO.swift`
  - `LifeLoop/Features/Organizer/Data/APIItemRepository.swift`
  - `LifeLoop/Features/Organizer/Presentation/ItemsListViewModel.swift`
  - `LifeLoop/LifeLoopTests/APIContractTests.swift`
- **Swift code example**:
```swift
// APIItemRepository.swift
func confirmReviewItem(id: UUID, expectedRevision: Int?) async throws -> LifeItem {
    guard let expectedRevision, expectedRevision > 0 else {
        throw ItemMutationError.invalidRevision
    }
    let payload = ConfirmReviewRequest(expectedRevision: expectedRevision)
    let body = try JSONEncoder().encode(payload)
    let responseData: Data
    do {
        let (data, _) = try await client.request(
            "api/v1/items/\(id.uuidString.lowercased())",
            method: "PATCH", body: body, authenticated: true
        )
        responseData = data
    } catch APIError.conflict {
        throw ItemMutationError.conflict
    }
    let response = try JSONDecoder().decode(ItemResponse.self, from: responseData)
    let canonicalItem = try response.item.domainValue()
    guard canonicalItem.id == id,
          let canonicalRevision = canonicalItem.revision,
          canonicalRevision > expectedRevision else {
        throw APIError.invalidResponse
    }
    return canonicalItem
}
```

---

### 8. UI Tests and Testing Boundaries
- **Why it was used**:
  - Unit tests run headless and fast, but cannot catch layout regressions, hit-testing failures, view hierarchy clippings, or broken accessibility labels.
  - `OrganizerUITests` runs in the real iOS simulator to validate end-to-end user interactions on device layouts.
- **How it works**:
  - UI components define explicit accessibility identifiers (e.g. `quickCaptureButton`, `itemTitleField`, `chevronExpand-<id>`, `receivedItem-<id>`).
  - In `testPriorityTabComponentsAndWaitingForActions`, the test launches with `--ui-testing`:
    1. Verifies the Quick Capture Floating Action Button is gated and hidden (`XCTAssertFalse(app.buttons["quickCaptureButton"].exists)`).
    2. Validates section header visibility (`REMINDERS & DUE TODAY`, `NEEDS ATTENTION`, `TODAY`).
    3. Swipes down to find the Waiting For section and verifies item existence.
    4. Taps `chevronExpand-<id>` to expand the disclosure card.
    5. Asserts the 3 specialized Waiting For buttons are rendered: `receivedItem-...`, `remindLaterItem-...`, and `followUpItem-...`.
  - **Testing Boundary Note**:
    - Simulator UI tests use `--ui-testing` with deterministic in-memory fixtures (`SampleItemRepository`).
    - Simulator tests validate SwiftUI rendering, navigation, and user interaction mechanics, but **do not validate the live backend**, network cookies, Postgres migrations, or server-side latency. Live backend verification is performed separately via targeted API contracts and deployed testing.
- **Key files**:
  - `LifeLoop/LifeLoopUITests/OrganizerUITests.swift`
  - `LifeLoop/Features/Organizer/Presentation/ItemRowView.swift`
  - `LifeLoop/Features/Organizer/Presentation/ItemsListView.swift`
- **Swift code example**:
```swift
func testPriorityTabComponentsAndWaitingForActions() {
    let app = XCUIApplication()
    app.launchArguments.append("--ui-testing")
    app.launch()

    // 1. Verify Quick Capture FAB is gated and hidden until F1.2
    XCTAssertFalse(app.buttons["quickCaptureButton"].exists)

    // 2. Verify Section Headers
    XCTAssertTrue(app.staticTexts.containing(
        NSPredicate(format: "label CONTAINS[c] 'REMINDERS & DUE TODAY'")
    ).firstMatch.waitForExistence(timeout: 5))

    // 3. Scroll to and verify Waiting For Section
    let itemID = "00000000-0000-0000-0000-000000000007"
    let waitingItem = app.descendants(matching: .any)["item-\(itemID)"]
    var attempts = 0
    while !waitingItem.isHittable && attempts < 5 {
        app.collectionViews.firstMatch.swipeUp()
        attempts += 1
    }
    XCTAssertTrue(waitingItem.waitForExistence(timeout: 5))

    // 4. Tap expand chevron and verify 3 Waiting For action buttons
    app.buttons["chevronExpand-\(itemID)"].tap()
    XCTAssertTrue(app.buttons["receivedItem-\(itemID)"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["remindLaterItem-\(itemID)"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["followUpItem-\(itemID)"].waitForExistence(timeout: 3))
}
```

---

### 9. Grouping Unit Tests and Test Isolation Pattern
- **Why it was used**:
  - Date calculation logic is easily susceptible to flaky test failures if tests rely on the system clock (`Date()`).
  - Tests running at 11:59 PM or across midnight can flip items between `today` and `overdue` mid-run.
  - Tests executing on developer machines in different time zones (e.g. UTC, PST, IST) could produce inconsistent results if local device calendars are used.
- **How it works**:
  - `TimelineGrouping.group(items:referenceDate:calendar:)` exposes explicit parameters for `referenceDate` and `calendar`, with sensible defaults for production.
  - In unit tests (`TimelineGroupingTests`, `PriorityGroupingTests`), a deterministic reference date fixture is provided (e.g. `2026-11-18 12:00:00 UTC`), paired with an explicit Gregorian UTC Calendar (`cal.timeZone = TimeZone(secondsFromGMT: 0)!`).
  - This guarantees complete test isolation:
    - Items constructed relative to `referenceDate` always fall into their intended bucket.
    - Tests never fail due to local machine time, daylight saving adjustments, or time-of-day execution.
- **Key files**:
  - `LifeLoop/LifeLoopTests/TimelineGroupingTests.swift`
  - `LifeLoop/LifeLoopTests/PriorityGroupingTests.swift`

---

## 5. Summary of F1.1 Verification & Test Metrics

- **Total Test Suite Execution**: **105 test declarations (100 unit tests + 5 UI tests)**, with 0 failures across both iPhone and iPad simulator destinations (iOS 26.5).
  - **Unit Tests (`LifeLoopTests`)**: **100 passed, 0 failed** across 10 suites:
    1. `APIContractTests` (38 tests) — added contract tests for confirm review PATCH, invalid revision rejection, HTTP 409 conflict propagation, and non-advancing revision rejection.
    2. `ItemsListViewModelTests` (18 tests) — added tests for invalid revision rejection and conflict error propagation.
    3. `TimelineGroupingTests` (8 tests)
    4. `AccountViewModelTests` (7 tests)
    5. `CachedItemRepositoryTests` (6 tests)
    6. `AccountLocalStoreTests` (5 tests)
    7. `GoogleOAuthConfigurationTests` (5 tests)
    8. `SampleItemRepositoryTests` (5 tests)
    9. `AppConfigurationTests` (4 tests)
    10. `PriorityGroupingTests` (4 tests)
    *Note on parameterized tests*: Swift Testing declares exactly 100 `@Test` functions in `LifeLoopTests`. Parameterized functions (`confirmReviewPatchRejectsInvalidRevisionBeforeNetworkRequest` [3 cases], `titlePatchRejectsInvalidRevisionBeforeNetworkRequest` [3 cases], `httpFailuresDoNotDecodeAsSuccess` [7 cases], `connectedEnvironmentRejectsInvalidServer` [4 cases], `missingConfigurationCannotStartGoogleSignIn` [3 cases]) expand to 16 case executions at runtime, executing 111 test cases in ~2.06s.
  - **Device-Specific Execution Times**:
    - **iPhone 17 Pro**: 100 unit tests in 2.111s; 5 UI tests in 91.780s.
    - **iPad Pro 13-inch (M5)**: 100 unit tests in 2.066s; 5 UI tests in 89.750s.
- **iPad Adaptive Navigation & UI Testing Learnings**:
  - In `NavigationSplitView` on iPad, the sidebar list and detail pane display concurrently. UI automation gestures must target `app.collectionViews.firstMatch` directly; generic `app.swipeUp()` directs swipes to the center detail pane.
  - Custom grouped cells containing inline action buttons (e.g. Confirm AI review, Snooze, Edit, Delete) benefit from explicit tap offsets (`coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))`) to guarantee row selection without triggering nested controls.
  - When dismissing full-screen covers or sheets, explicitly awaiting `.waitForNonExistence` on the dismissed view prevents accessibility event drops (`kAXErrorServerNotFound`) during window server transitions.
- **Code Health**:
  - 0 Swift concurrency warnings (Swift 6 strict concurrency verified).
  - 0 compiler deprecation warnings.
  - 0 trailing whitespace violations (`diff --check` clean).
