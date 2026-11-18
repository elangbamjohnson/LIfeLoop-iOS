# LifeLoop iOS: learn the application through its code

**Code snapshot: 18 November 2026.** This guide describes the local working tree on `feat/ios-revision-aware-title-editing`, including uncommitted changes. It is a learning companion to the master development guide, not a claim that Phase 2 is finished or that every path has passed testing.

The current code enables connected **title editing** through `OrganizerCapabilities.titleOnly`. Connected create, complete, reopen, and delete remain blocked. This is newer than the earlier plan to keep all connected editing disabled.

No application code was changed or tests rerun to prepare this document. Existing test source was inspected. The earlier `IOS_TECH_STACK_AND_LEARNING.md` is preserved separately.

## How to use this guide

Read sections 1–5 first. Then follow one complete flow in sections 6–10 with Xcode open. Read the testing section before changing behavior. Section 14 records limitations so that intended design is not confused with complete implementation.

The most useful question while reading any file is: **what responsibility does this file own, and which responsibility does it delegate?**

## 1. The application in one picture

LifeLoop iOS is a native client of the existing LifeLoop service. The service owns the authoritative account and item data. The phone owns presentation, temporary editing state, a cached copy of items, and a local session credential.

```text
SwiftUI screen
    ↓ user action
Observable view model
    ↓ repository protocol
CachedItemRepository → AccountLocalStore → SwiftData
    ↓ remote repository
APIItemRepository / APIAccountRepository
    ↓
APIClient → HTTPTransport → URLSession → LifeLoop backend
    ↑                                     ↓
    └──────────── response JSON ───────────┘
```

Google sign-in is a separate identity step. Google proves who the person is; LifeLoop decides which account and application session that identity can use. The app does not connect directly to the server's database.

## 2. Technology inventory: what, why, and where

| Technology | Plain-language purpose | Why it is used here / what it accomplishes | Code to inspect |
|---|---|---|---|
| Swift 6 language mode | The implementation language | Structs, enums, protocols, optionals, and concurrency checks express the app's data and behavior | App target build settings; all `.swift` files |
| Foundation | Standard data and system utilities | URLs, dates, UUIDs, JSON coding, errors, string trimming, and HTTP request types | `LifeItem`, `JSONValue`, `APIClient` |
| SwiftUI | Describe what the screen should look like for a given state | Shared native iPhone/iPad UI with adaptive navigation and system controls | `RootView`, `ItemsListView`, `ItemEditView` |
| Observation (`@Observable`) | Track changes to model properties read by views | Refresh affected UI when a view model changes | `ItemsListViewModel`, `AccountViewModel` |
| Swift concurrency | Suspend work while waiting and coordinate access to state | Network calls do not block the UI while waiting; cancellation and actor isolation control asynchronous work | `async throws`, `await`, `Task`, `@MainActor` |
| URLSession | Apple's HTTP client | Send requests without an additional networking library | `URLSessionTransport.send(_:)` |
| Codable, JSONEncoder, JSONDecoder | Convert Swift values to/from JSON | Define request bodies, decode responses, and serialize cached data | DTOs, `AccountLocalStore` |
| Security / Keychain | OS-managed credential storage | Keep the LifeLoop session token out of ordinary preference files | `KeychainSessionCredentialStore` |
| SwiftData | On-device persistence | Retain item snapshots and drafts across launches | `LocalRecord`, `AccountLocalStore` |
| GoogleSignIn | Google's native sign-in SDK | Obtain a Google ID token through the SDK flow | `GoogleSignInService` |
| GoogleSignInSwift | SwiftUI integration for the Google button | Present the SDK's sign-in control | `GoogleSignInWelcomeView` |
| UIKit bridge | Access a presentation controller from SwiftUI | Present Google sign-in from the correct window | `GooglePresentationAnchor` |
| Swift Package Manager | Resolve external libraries | Xcode downloads pinned Google SDK dependencies | `Package.resolved` |
| Swift Testing | Unit and contract test framework | Check model behavior and request/response rules with fakes | `LifeLoopTests`, `@Test`, `#expect` |
| XCTest / XCUITest | Drive the running application UI | Check navigation, editing, rotation, and selected accessibility properties | `OrganizerUITests` |
| Xcode, Simulator, xcodebuild | Build and run Apple applications | Interactive development and reproducible command-line validation | Xcode project, shared scheme, test script |
| xcconfig and generated Info.plist values | Separate build settings from application logic | Choose demo/staging/production and supply public OAuth configuration | `Configuration`, `AppConfiguration` |
| Git and GitHub Actions | Version control and automated verification | Review changes in branches and run simulator checks in CI | `.github/workflows`, `scripts/test-ios.sh` |
| Bash and Python 3 | Small automation helpers | Run xcodebuild and select an installed simulator from JSON | `scripts/test-ios.sh` |
| SF Symbols and Dynamic Type | System icons and text scaling | Familiar controls and support for larger text | `Image(systemName:)`, semantic fonts, previews |

The app target specifies iOS **17.6**, Swift **6.0 language mode**, default actor isolation **MainActor**, and device families **1,2** (iPhone and iPad). Some project-level settings specify a newer deployment target; inspect the app target's effective settings when troubleshooting. A language-mode setting does not identify the exact compiler version.

The checked-in dependency lockfile pins GoogleSignIn **9.0.0**. It also lists AppAuth-iOS 2.1.0, GTMAppAuth 5.0.0, GTMSessionFetcher 3.5.0, GoogleUtilities 8.1.5, AppCheck 11.3.2, Google SDK interop 101.0.0, and Promises 2.4.1. These are resolved SDK dependencies, not eight separate architectural choices made by our app. An AppCheck package appearing in the lockfile does **not** prove the application configures or enforces App Check.

The surrounding web system uses TypeScript/React, a Node-compatible Express API, Drizzle ORM, and PostgreSQL; Render hosts the deployed backend. These belong to the existing service, not the iOS binary. Our current native responsibility is to honor its HTTP contract. This guide does not attempt to inventory every web-only dependency.

## 3. Project structure and where new work belongs

```text
LifeLoop-iOS/
├── LifeLoop/
│   ├── App/
│   │   ├── LifeLoopApp.swift             Application entry point
│   │   ├── RootView.swift                Organizer navigation and editor ownership
│   │   ├── Configuration/               Configuration validation and service assembly
│   │   ├── Networking/                  APIClient and HTTP transport
│   │   └── PreviewContent/              Demo items and sample repository
│   ├── Configuration/                   Demo/Staging/Production xcconfig files
│   ├── Features/
│   │   ├── Account/
│   │   │   ├── Domain/                  Account and identity/repository contracts
│   │   │   ├── Data/                    Backend account adapter and credential store
│   │   │   ├── Google/                  SDK configuration/service/presentation bridge
│   │   │   └── Presentation/            Account UI, state, connected organizer assembly
│   │   └── Organizer/
│   │       ├── Domain/                  Item values, repository, capabilities, errors
│   │       ├── Data/                    API DTOs and caching adapter
│   │       ├── Persistence/             SwiftData snapshots and drafts
│   │       └── Presentation/            List, row, detail, editor, view model
│   ├── LifeLoopTests/                   Swift Testing suites
│   ├── LifeLoopUITests/                 XCTest UI suite
│   └── LifeLoop.xcodeproj/              Targets, settings, shared scheme, package pins
├── scripts/test-ios.sh
├── .github/workflows/                  CI workflow
└── docs/                               Development plan and learning material
```

These feature folders provide **logical separation within an app target**. They are not independently compiled Swift packages. Moving files into folders alone does not enforce architecture boundaries.

For a future Capture feature, begin with `Features/Capture` and its own UI/state/contracts. Reuse the authenticated client and account identity. Add a shared abstraction only when multiple features genuinely need it; avoid a miscellaneous “manager” holding every feature's behavior.

## 4. Architecture: feature-based MVVM with repository boundaries

**MVVM** means Model–View–ViewModel:

- **Model:** `LifeItem`, `ItemStatus`, `Account`, and associated data rules.
- **View:** SwiftUI structs describe presentation and forward actions.
- **ViewModel:** observable classes own screen state and coordinate repository operations.

The repository boundary introduces Clean Architecture ideas: UI logic can depend on an interface rather than knowing HTTP or storage details. However, this is **not a strict, fully isolated Clean Architecture implementation**. There is no separate use-case/interactor layer, and some presentation code still references `APIError` and `AccountLocalStore`. `APIAccountRepository` also reuses a cache policy from `CachedItemRepository`.

This size of application benefits from the current lightweight structure. A separate use-case can be introduced when an operation becomes complex or reused. VIPER's additional presenter/interactor/router types would currently add substantial navigation between files without an established need.

### Dependency injection versus dependency inversion

`ItemsListViewModel.init(repository: any ItemRepository)` demonstrates both concepts, for different reasons:

- **Dependency injection is the mechanism:** another object supplies the repository through the initializer.
- **Dependency inversion is the design:** the view model depends on `ItemRepository`, a contract, rather than constructing `APIItemRepository` itself.

`any ItemRepository` means “a value of some concrete type that satisfies this protocol.” The runtime object can be an API repository, a cache wrapper, a sample repository, or a test fake.

`AppComposition` and `ConnectedServices` are the main **composition root**: the place where concrete services are created and connected. Screens receive what they need afterward. `ConnectedOrganizerView` adds the account-specific cache wrapper once an account is available.

### SOLID, using actual examples

| Principle | Meaning here | Example and honest boundary |
|---|---|---|
| Single responsibility | Keep one main reason to change per component | `ItemDTO.domainValue()` maps data; `APIClient.request` handles HTTP/session rules; `ItemRowView` draws a row |
| Open/closed | Add behavior through an existing contract | A fake transport can be added without rewriting `APIClient` |
| Liskov substitution | Implementations should honor their shared contract | Both sample and API title updates reject stale revisions; do not assume every repository supports every mutation |
| Interface segregation | Consumers should need only relevant contracts | `GoogleIdentityProvider` is small; `ItemRepository` is broader and may eventually split into read/title/other mutation interfaces |
| Dependency inversion | Higher-level decisions depend on abstractions | View model → repository protocol; APIClient → HTTPTransport and SessionCredentialStore |

`OrganizerCapabilities` controls which controls are exposed; it does not enforce server authorization. `APIItemRepository` independently blocks unsupported mutations, and the backend must still authenticate and authorize every request.

## 5. Swift and SwiftUI concepts used throughout

### Structs, classes, protocols, and enums

`LifeItem` is a **struct**, a value type. Editing a local copy does not automatically edit the item in the list. `ItemsListViewModel` is a **class**, a reference type: the root and list can observe the same instance.

`ItemRepository` is a **protocol**, a required set of operations. `ItemStatus` and the view model's `State` are **enums**, restricting values to a defined set of cases. Associated values carry context: `.loaded([LifeItem])`, `.failed(String)`, `.unknown(String)`.

`revision: Int?` is optional because older responses/cache records can lack it. Missing data is not a reason to manufacture revision 1. `Identifiable` supplies stable IDs for lists; `Equatable` supports comparisons; `Codable` combines encoding and decoding.

### State ownership

| Construct | Example | Role |
|---|---|---|
| `@State` | `RootView.viewModel`, `editingItem`, `ItemEditView.draftTitle` | Store state associated with a SwiftUI view identity |
| `@Observable` | `ItemsListViewModel` | Track property reads and mutations for observation |
| `@Binding` | `ItemsListView.selectedItemID` | Read/write state owned elsewhere, here by RootView |
| `$value` | `$draftTitle` | Create a binding for a control such as TextField |
| `@Environment` | `dismiss`, `scenePhase` | Obtain context/actions supplied by SwiftUI |
| `private(set)` | `ItemsListViewModel.state` | Allow outside reads while restricting writes to the type |

`@Observable` is a macro, not a protocol conformance. It avoids manually publishing every property. This project does not use a Combine publisher pipeline for these view models.

SwiftUI can recreate view structs while preserving their state storage **as long as identity survives**. `_item = State(initialValue: item)` initializes the property's backing wrapper. It is not an instruction to overwrite the mounted editor's state every time its parent renders. Removing/reidentifying the view can still reset state.

### Callbacks and bindings in the editor

The text field binds to **local** `draftTitle`. On Save, `ItemEditView` calls `onSave(updatedItem)`; RootView connects that callback to `ItemsListViewModel.saveTitle`.

This separates typing from committing an asynchronous operation. Cancel removes the draft and dismisses without saving it to the repository. A binding directly to the shared item title would update that item while typing unless a separate draft/rollback mechanism were added. Bindings can support a draft-based editor too; callbacks are not required merely because Cancel exists.

The list updates because `saveTitle` calls `updateItem`, which replaces the item inside `.loaded(items)` and assigns the new state. The list observes the same view model. It does not need the editor's callback itself.

`guard case .loaded(var items) = state else { return }` means: “continue only if the state contains a loaded list, and extract a mutable local copy of that list.” Changing the copy alone is insufficient; `state = .loaded(items)` publishes the new value.

### Async work and actor isolation

`async` allows suspension; `await` marks a possible suspension; `throws` allows failure. `Task { ... }` bridges a synchronous button action into asynchronous work. `defer` runs cleanup when a function exits, such as removing an ID from `mutatingItemIDs`.

`@MainActor` coordinates access to UI-related state. It does not make every operation run on a background thread, and code can be interleaved while waiting at an `await`. URLSession performs asynchronous network work, but large synchronous decoding or computation on the main actor could still affect responsiveness.

Cancellation is cooperative: `Task.checkCancellation()` explicitly checks it. Cancelling a client task does not prove the backend did not apply a submitted write.

## 6. Startup and environment selection

Read [LifeLoopApp.swift](/Users/johnsonelangbam/Projects/LifeLoop-iOS/LifeLoop/App/LifeLoopApp.swift), then [AppComposition.swift](/Users/johnsonelangbam/Projects/LifeLoop-iOS/LifeLoop/App/Configuration/AppComposition.swift).

1. `LifeLoopApp` is the `@main` entry point and owns an `AppComposition` in state.
2. `AppConfiguration.init(values:)` reads generated Info.plist values.
3. Demo builds use sample data and a demo-scoped local store.
4. Connected builds create an `APIClient`, transport, Keychain store, account repository, item repository, and local persistence container.
5. `AccountView` chooses restoring, signed-out, or signed-in presentation.
6. Invalid configuration displays an unavailable screen instead of silently falling back to demo mode.

`Result<ModelContainer, Error>` retains either a successfully created store or its failure so the UI can show an appropriate state. It does not terminate the app just because storage initialization failed.

| Build configuration | xcconfig | Behavior in this working tree |
|---|---|---|
| Debug | Demo.xcconfig | Sample data; CI tests use this |
| Staging | Staging.xcconfig | Connected server |
| Release | Production.xcconfig | Connected server |

Both connected xcconfigs currently point to the **same Render URL**. The names do not establish separate databases or an isolated staging deployment. The production comment saying the server is unconfigured is stale relative to its actual URL value.

At the final documentation check, the shared scheme uses **Staging for Run** and **Debug for Test** (Run changed from Release to Staging while this guide was being prepared). Therefore pressing Run and running tests can show different experiences. Build configuration is independent from Apple distribution signing.

`https:/$()/...` in an xcconfig is intentional: an empty build-setting expansion separates the slashes so the parser does not treat `//` as a comment. Runtime validation requires HTTPS and rejects credentials, query parameters, and fragments in the configured base URL.

## 7. Google authentication, step by step

Read [AccountViewModel.swift](/Users/johnsonelangbam/Projects/LifeLoop-iOS/LifeLoop/Features/Account/Presentation/AccountViewModel.swift) alongside [GoogleSignInService.swift](/Users/johnsonelangbam/Projects/LifeLoop-iOS/LifeLoop/Features/Account/Google/GoogleSignInService.swift).

```text
GoogleSignInWelcomeView button
  → AccountViewModel.signInWithGoogle()
  → GoogleIdentityProvider.signIn()
  → GoogleSignInService / Google SDK → Google ID token
  → APIAccountRepository.signIn(googleIDToken:)
  → POST api/v1/auth/google
  → active account + LifeLoop session cookie
  → APIClient.saveSession → Keychain
  → AccountViewModel.state = .signedIn(account)
```

The **iOS client ID** identifies the native OAuth client registered for the bundle ID. The **server client ID** requests an ID token intended for the backend's configured audience. The **reversed iOS client ID** registers the callback URL scheme. These identifiers are public configuration, not client secrets.

`GoogleOAuthConfiguration` checks the two IDs and callback scheme. `GooglePresentationAnchor` implements `UIViewControllerRepresentable` to provide a controller from the current SwiftUI window. Its nested `AnchorController.viewDidAppear` reports the controller to the service. This avoids simply selecting an arbitrary application window on an iPad.

`GoogleSignInService.signIn()` presents the SDK, calls `refreshTokensIfNeeded()`, and extracts `idToken.tokenString`. The app entry point's `.onOpenURL` forwards callbacks to `GIDSignIn.sharedInstance.handle(url)`.

The backend, not the native UI, must validate the Google token. The native app then uses the returned **LifeLoop session** for item requests. It does not send the Google ID token for every item request.

SDK cancellation becomes `CancellationError`, which the view model avoids presenting as a login failure. `isBusy` prevents repeated sign-in taps. A generation counter stops an old sign-in result from restoring state after sign-out.

### Restoring and ending sessions

`AccountViewModel.restore()` calls `APIAccountRepository.currentAccount()`, which requests `api/v1/auth/me`. Certain connectivity failures can use a cached active account only while the stored credential is unexpired. An explicit unauthorized/forbidden response clears the session instead of falling back to cached identity.

`ConnectedOrganizerView`'s explicit sign-out action first calls `AccountLocalStore.purgeAndInvalidate()`, then invokes account sign-out. `APIClient.clearSession()` increments its generation and clears the credential. Google's local SDK session is also cleared.

Current local logout is **not server-side token revocation**. An unexpired credential's cached account also cannot prove that access was not revoked while offline. Keep those distinctions when planning account lifecycle work.

## 8. HTTP, credentials, and response mapping

Read [APIClient.swift](/Users/johnsonelangbam/Projects/LifeLoop-iOS/LifeLoop/App/Networking/APIClient.swift).

`HTTPTransport.send(_:)` abstracts the actual network. `URLSessionTransport` uses an ephemeral session, disables shared cookie storage and URL caching, sets a request timeout, and refuses redirects. The app manages its session cookie explicitly rather than sharing browser-like cookie state.

`APIClient.request`:

1. Builds the URL and HTTP method/body.
2. Adds JSON headers and `X-Timezone`.
3. Reads an unexpired credential when authentication is required.
4. Adds `Cookie: session=...`.
5. Awaits the transport and checks cancellation/session generation.
6. Returns successful data or maps status codes to `APIError`.

401 means unauthorized; 403 means forbidden; 409/412 become conflict; 429 becomes rate-limited. Other unsuccessful statuses use `.server(status)`. This is a deliberately small mapping; it does not currently retain every structured backend error field, such as `currentRevision`.

`saveSession(from:account:)` requires a nonempty session cookie with an explicit future expiry. It does not invent an expiry for a session-only cookie.

`KeychainSessionCredentialStore.read/save/clear` use `SecItemCopyMatching`, `SecItemUpdate`/`SecItemAdd`, and `SecItemDelete`. The stored Codable credential contains token, expiry, and optional account. Its service key includes the server address. `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` limits availability to the unlocked device and does not make this a cross-device credential sync mechanism.

The Keychain service prefix still contains `com.personal.LifeLoop`; it is a storage identifier, distinct from the app's current bundle ID `com.johnson.LifeLoop`. Changing that identifier casually would make existing credentials appear missing.

### DTOs protect the UI from wire-format details

`ItemDTO` is a **Data Transfer Object**: the shape received from the API. `domainValue()` converts string statuses and ISO-8601 date strings into app values. It supports timestamps with and without fractional seconds and rejects unreadable non-null dates.

`JSONValue` is a recursive enum preserving JSON strings, Decimal numbers, booleans, objects, arrays, and nulls. It keeps unfamiliar metadata available even when the UI cannot display all of it. `ItemStatus.unknown(String)` similarly preserves unfamiliar statuses.

`ItemDetailView` displays selected known metadata and an additional-information notice for other fields. Preserving data does not mean every field already has a native editor.

## 9. Loading and presenting items on iPhone and iPad

`ItemsListView` starts `loadIfNeeded()` in `.task(id: retryCount)`. Pull-to-refresh calls `forceLoad()`. Returning to the foreground triggers a refresh if `isStale` reports more than five minutes since loading.

`ItemsListViewModel.load()` asks the repository for items and sets one of `idle`, `loading`, `loaded`, `empty`, or `failed`. A generation counter prevents an older load's result from replacing a newer one. An empty response is a valid state, not a network error.

`RootView` owns a `NavigationSplitView`. It adapts list/detail presentation to available space. Selection is a UUID, and `selectedItem` looks up that ID in the current view-model list; this helps detail follow canonical updates rather than retaining an unrelated stale copy.

The root also owns `editingItem` and `.fullScreenCover`. Keeping editor ownership above the adaptive columns helps preserve editing when the device rotates or the navigation arrangement changes. Inside the cover, `NavigationStack` supplies editor title/toolbars.

`ItemRowView` combines accessibility elements for its title/status and shows a progress indicator while its ID is in `mutatingItemIDs`. Semantic fonts scale with Dynamic Type. Stable accessibility identifiers give UI tests reliable ways to find controls; identifiers are different from user-facing accessibility labels.

## 10. Saving a title and understanding revision conflicts

Read [ItemEditView.swift](/Users/johnsonelangbam/Projects/LifeLoop-iOS/LifeLoop/Features/Organizer/Presentation/ItemEditView.swift) and [APIItemRepository.swift](/Users/johnsonelangbam/Projects/LifeLoop-iOS/LifeLoop/Features/Organizer/Data/APIItemRepository.swift).

```text
User types → local draftTitle
Save → ItemEditView.save()
     → RootView's onSave closure
     → ItemsListViewModel.saveTitle(for:newTitle:)
     → CachedItemRepository.updateItem
     → APIItemRepository.updateItem
     → authenticated PATCH { title, expectedRevision }
     ← canonical item from server
     → attempt local snapshot update
     → replace item in view-model state
     → remove draft and dismiss editor
```

`trimmedTitle` removes whitespace/newlines at the edges. This is string normalization; `map` transforms elements and is not a direct substitute for trimming. Empty normalized titles cannot save.

The editor copies its item and sets the draft title and captured revision. `saveTitle` checks revision validity, tracks the in-flight item ID, and waits for repository acknowledgement. This is an **acknowledged save**, not an immediate optimistic replacement of the list title.

`UpdateItemTitleRequest` encodes only `title` and `expectedRevision`. Sending a complete old item could overwrite unrelated metadata changed elsewhere. The repository validates the response ID and requires its revision to be greater than the submitted revision before returning the canonical item.

### Why an integer revision matters

Suppose web and iPhone both read revision 4. Web saves first; the server advances to 5. The phone's `expectedRevision: 4` is now stale, so the backend rejects it with HTTP 409. Without a server-enforced comparison, the last request could overwrite someone else's change silently.

This is **optimistic concurrency control**: editing does not hold a database lock for the entire time a person types. The server checks the revision when applying the write. The integer alone is insufficient; all relevant server writers must participate and comparison/update must be atomic. It does not guarantee every transaction in the system is serializable.

`APIClient` maps the HTTP conflict to `APIError.conflict`; `APIItemRepository` maps it to `ItemMutationError.conflict`. `ItemEditView.save()` retains the draft and exposes “Reload latest item.” There is no application-level automatic retry loop in this path.

`reloadItem()` currently changes the editor's base item/revision while keeping the typed title. A later Save is a new explicit submission. This is basic recovery, not a complete comparison/merge UI: the latest server title is not separately displayed for comparison. See section 14 before treating this path as production-complete.

## 11. SwiftData: cache, draft, and account isolation

Read [AccountLocalStore.swift](/Users/johnsonelangbam/Projects/LifeLoop-iOS/LifeLoop/Features/Organizer/Persistence/AccountLocalStore.swift).

Three kinds of state have different jobs:

| State | Owner/storage | Lifetime and meaning |
|---|---|---|
| Screen state | View model / SwiftUI state | What the current screen is doing |
| Item snapshot | SwiftData JSON payload | Last locally saved copy of server items; may be stale |
| Draft | SwiftData JSON payload plus editor state | Unsubmitted title and its base information |

`LocalRecord` is an `@Model` class with unique key, scope, binary payload, and saved date. Rather than making every backend field a SwiftData column, the store encodes whole snapshots/drafts as JSON in `Data`. This simplifies preserving flexible metadata but is less suited to querying individual item fields in the database.

`makeContainer(inMemory:)` constructs the persistence container, disables CloudKit integration, and can use in-memory storage for tests. `ModelContext` manages reads/changes. Autosave is disabled; explicit `save()` rolls back the context on failure.

Keys include `server|accountID|recordName`. `saveItems/readItems` operate on the item snapshot; `saveDraft/draft/removeDraft` operate on a particular item's draft. `purgeAndInvalidate()` makes the store inactive before removing the account's records, so a later write using that store cannot recreate them.

`CachedItemRepository` is a **decorator**: it implements the same interface as the remote repository while adding local behavior. `fetchItems()` prefers the server, saves the snapshot, and falls back only for selected connectivity errors. An unauthorized response does not fall back to cached items. `cacheDate` tells the UI to show “Offline · Saved …”. There is no general offline mutation queue.

After a successful title update, the wrapper attempts `store.updateItem(updated)`. That method replaces an existing item in an existing snapshot. It does not create a full cache from a single item if no snapshot exists. The wrapper uses `try?`, so cache persistence failure is ignored and server success still returns. This avoids claiming the remote save failed, but can leave an older offline snapshot without a warning.

`ItemDraft` preserves `baseRevision: String?` for legacy timestamp data and adds `baseItemRevision: Int?`. Its custom decoder accepts missing fields. Backward-compatible decoding and a safe editing policy for old drafts are separate problems; section 14 explains the remaining policy gap.

## 12. Tests: what each layer proves

Tests are executable examples of intended behavior. They are not proof of every production condition.

| Suite | Learning focus / examples in current source |
|---|---|
| `AppConfigurationTests` | Missing config fails closed; connected URLs require HTTPS |
| `GoogleOAuthConfigurationTests` | OAuth IDs and callback configuration validation |
| `AccountViewModelTests` | Login, restoration, cancellation, repeated taps, late results |
| `APIContractTests` | Cookie expiry, stale-session responses, DTO mapping, exact PATCH payload, invalid revisions, conflict/no-retry behavior |
| `ItemsListViewModelTests` | Loaded/empty/failure states; retry; saving canonical item state |
| `SampleItemRepositoryTests` | Demo title revisions, stale/missing revisions |
| `AccountLocalStoreTests` | Persistence/account boundaries |
| `CachedItemRepositoryTests` | Offline fallback, disk reopen, canonical cache reconciliation |
| `OrganizerUITests` | Cancel/save, rotation, blank title, empty/failure UI, selected accessibility checks |

`#expect(condition)` in Swift Testing serves the assertion role that `XCTAssert...` serves in XCTest, with different APIs and diagnostics. `#require` can stop the current test early when a prerequisite is absent. A `guard case` followed by `Issue.record(...)` is also a real check: an unexpected enum case records failure even without a `#expect` on that line. Read the entire test body before concluding it has no assertion.

`loadHandlesEmptyResponse()` teaches that an empty repository result should become `.empty`. To explore a failing test, temporarily make the fake return a nonempty array or change the expected state, run that test, inspect the failure, and revert the experiment before committing.

Contract tests inject `HTTPTransport` and credential-store fakes so they can inspect requests without a live account. A SwiftData in-memory container avoids polluting personal data. UI tests launch demo mode with arguments such as `--ui-testing`, `--empty-items`, and `--failed-items`.

The accessibility audit currently requests element detection and sufficient descriptions. Passing it does not establish complete VoiceOver, contrast, or accessibility compliance. Demo UI tests do not exercise real Google consent, a real backend conflict, or a deployed database migration.

## 13. CI, packages, and a practical learning loop

The GitHub Actions workflow runs on pushes, pull requests, and manual dispatch. It defines:

- An iPhone/iPad test matrix on `macos-26`, selecting Xcode 26.6.
- Debug unit/contract/UI tests through `scripts/test-ios.sh`.
- Separate unsigned simulator builds for Staging and Release.
- Test-result bundles (`.xcresult`) and logs retained as artifacts for seven days.

These describe the checked-in workflow, not a fresh CI run or a guarantee that the selected hosted Xcode path will always exist.

The Bash test script uses `set -euo pipefail`; its small Python helper reads `simctl` JSON to select an available simulator. `xcodebuild` pins resolution with `-onlyUsePackageVersionsFromResolvedFile`, disables signing, and disables parallel testing for the run.

From the repository root, the existing local entry points are:

```bash
DEVICE_FAMILY=iPhone bash scripts/test-ios.sh
DEVICE_FAMILY=iPad bash scripts/test-ios.sh
```

These require Xcode and suitable installed simulator runtimes. They are examples to run when validating code changes; they were not executed for this documentation task. Simulator builds do not produce a signed App Store archive.

For each increment: read the relevant contract, make one behavior change, run focused tests, then run broader required checks. Review the diff before committing. Do not change the master guide's entire phase scope just because one feature works.

## 14. Current limitations worth learning from

These are source observations, not a complete audit or newly reproduced runtime failures. They explain why a good architectural direction still needs careful integration work.

1. **Architecture boundaries are partial.** View models reference `APIError`; views access the persistence store. Avoid documenting presentation as dependent only on domain protocols.
2. **Conflict review is incomplete.** Reload retains the typed title and adopts a returned revision without separately showing the latest server title. RootView's reload closure calls `forceLoad()`, which can use cached reads, and returns the original item if no matching loaded item is available. “Reload latest” therefore does not guarantee a fresh online item in every path.
3. **Legacy draft safety needs review.** If a draft has no integer base revision, editor initialization begins with the current item's revision. A legacy timestamp mismatch sets a conflict message, but `save()` does not block solely on that flag. Decoding old drafts correctly does not by itself prevent an old title from being rebased onto a newer item.
4. **Reload persistence/cleanup needs review.** Reload changes the base revision without explicitly resaving the draft unless the title changes afterward. A cancellation return inside `reloadItem()` can bypass the final reset of `isReloading`.
5. **Save-time expiry differs from load-time expiry.** `load()` sets `requiresSignIn` on unauthorized errors; `saveTitle()` currently propagates errors without setting that flag. Explicit sign-out purges local records, while the automatic expiry callback follows a different path.
6. **Cache updates are best effort.** `try? store.updateItem` suppresses errors after an acknowledged save. Updating one item also refreshes the whole snapshot's saved timestamp, although other items were not fetched again.
7. **Demo behavior is not a complete server simulation.** Sample title edits enforce/increment revisions, but `SampleItemRepository.createItem()` currently creates an item without a revision. Other sample mutations are simpler than real backend operations.
8. **Environment separation is not established.** Staging and Production currently share a URL. The production configuration comment and earlier planning documents can lag behind code.
9. **Title editing is enabled but release readiness is separate.** Connected other mutations, complete account lifecycle behavior, remaining Phase 2 features, and distribution checks are not completed merely by enabling `.titleOnly`.

Do not “fix” these by automatically retrying writes or replacing unknown revisions with a default. A network timeout can mean the server saved successfully but the response was lost. A later conflict may require reconciliation with the current server state.

## 15. Suggested reading exercises

| Read these files together | What to explain in your own words |
|---|---|
| `LifeLoopApp` → `AppComposition` → `AppConfiguration` | Why Run can use connected data while tests use demo data |
| `ItemRepository` → `SampleItemRepository` → `ItemsListViewModel` | Dependency injection versus dependency inversion |
| `RootView` → `ItemsListView` → `ItemEditView` | Who owns selection, the view model, and the unsaved title |
| `GoogleSignInService` → `APIAccountRepository` → `APIClient` | Google identity token versus LifeLoop session cookie |
| `APIItemRepository` → `ItemDTO` → `JSONValue` | How unfamiliar backend data survives native mapping |
| `CachedItemRepository` → `AccountLocalStore` | Why a draft, a cache, and the authoritative server are different |
| `saveTitle` → `APIContractTests` | Why an integer revision must be checked by the server |
| `OrganizerUITests` → CI workflow | What automated checks prove and what still requires manual verification |

Try tracing “Save title” on paper without skipping a layer. At each step, identify the input, output, possible failure, and state owner. Then find the test that would fail if that step behaved incorrectly.

## 16. Short glossary

| Term | Meaning in this project |
|---|---|
| Composition root | Where concrete dependencies are assembled |
| Repository | Interface for obtaining/changing application data |
| Adapter | Converts one interface or data representation into another |
| Decorator | Wraps a repository with extra behavior while keeping its interface |
| DTO | JSON-facing value mapped to the app's domain value |
| Canonical item | The server-returned authoritative representation after a save |
| Revision | Version number used to reject a stale update |
| Draft | Local, unsubmitted user input |
| Cache | A stored copy that can be older than the server |
| Generation counter | Number checked to reject results from an obsolete operation/session |
| Actor isolation | Rules coordinating access to state across concurrent work |
| Contract test | Checks agreed request/response behavior against controlled examples |
| Capability | Local feature availability; not a substitute for server permission checks |

As implementation changes, update the examples and the limitations together. The development master guide defines the destination; this document explains the code that currently exists.
