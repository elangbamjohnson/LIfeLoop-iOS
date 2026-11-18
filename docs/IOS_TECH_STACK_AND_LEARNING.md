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
