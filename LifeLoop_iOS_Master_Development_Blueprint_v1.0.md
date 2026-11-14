# LifeLoop iOS — Master Development Blueprint

**Version:** 1.0  
**Date:** 14 November 2026  
**Platforms:** iPhone and iPad  
**Status:** Foundational architecture and delivery plan — review and update by architecture decision records  
**Source repository:** https://github.com/elangbamjohnson/LifeLoop  
**Repository baseline inspected:** `main`, commit `1e268acccac2a8a644a27e243801ddc94bba8f65` (23 October 2026)  
**Document owner:** LifeLoop iOS project  
**Implementation code included:** None

> **Project charter.** Build LifeLoop as a genuinely native, maintainable, testable iOS application while deliberately learning the underlying technology. Release useful, vertically complete slices rather than rebuilding the entire web application at once. Retain the existing LifeLoop backend as the system of record unless a recorded decision justifies change.

## 1. Executive decisions

1. **App technology:** Swift, SwiftUI, structured Swift Concurrency, URLSession, Swift Package Manager (SPM), XCTest/Swift Testing and Xcode UI tests.
2. **Architecture:** Pragmatic Clean Architecture + MVVM, with feature-oriented modules, protocol-based dependency injection and an app composition root. Avoid VIPER and TCA initially.
3. **Backend:** Reuse the existing Express REST API, PostgreSQL data, Gemini processing and server-side reminder logic. Do not duplicate backend business rules on the device.
4. **UI:** Native, adaptive iPhone and iPad UI. Do not reproduce web layout pixel for pixel. Keep familiar LifeLoop concepts and terminology.
5. **Delivery:** Every phase must end in a tagged, manually usable TestFlight build. Public App Store release starts only when its privacy, reliability and backend gates pass.
6. **Learning:** Each phase includes a focused learning syllabus, experiments, conceptual review and measurable exit criteria.
7. **Core product promise:** Capture what matters, understand it, act in time and optionally coordinate with family.
8. **Scope discipline:** Only build the next planned vertical slice; postpone abstract frameworks and advanced features until there is a proven need.

## 2. What the existing repository actually contains

**Verified from source:** React 19/TypeScript/Vite frontend; Express/TypeScript REST backend; PostgreSQL/Drizzle; user registration, login, Google identity verification, email verification and cookie sessions; raw text/media captures; server-side Gemini extraction with fallback/retry; structured items; item completion, snooze, update, deletion and timeline grouping; scheduled reminders with recurring/relative rules; a family/membership/sharing API; Ask My Life; item relations/graph; server-sent events (SSE) and polling; Vitest and Playwright tests.

**Main UI sections:** Priority, Timeline, Inbox/Captures, Family; Ask and Graph are restricted to admins in the current web client. **Primary server routes:** `/api/v1/auth`, `/captures`, `/items`, `/reminders`, `/families`, `/ask`, `/relations`, `/events`.

**Important distinctions:** The repository contains responsive web tests, but no native iOS source or native test coverage. The QA report is a dated snapshot from September 2026, not evidence that the latest commit's tests were executed for this plan. Historical documents such as `SCHEMA.md`, `DEVELOPMENT.md` and `TEST_AUDIT.md` do not fully match later source code; executable routes, schema and tests take precedence until documentation is reconciled.

### Findings that influence the iOS roadmap

- **iOS push is not implemented:** `IOSNotificationProvider` builds a proposed APNs payload but returns success without actually sending it. Never advertise remote push as working until the backend sends it and a physical device receives it.
- **Auth is cookie-based:** `requireAuth` reads the `session` HTTP-only cookie, not a bearer access token. Do not build a refresh-token system that the server does not support.
- **Publicly served uploads need a security review:** the backend exposes `/uploads` as static files. This may be unsuitable for private document/images; protect access before publicly releasing media capture.
- **SSE is an optimization, not the source of truth:** server events and foreground polling refresh client state; a disconnected or suspended iOS client needs a normal REST reconciliation path.
- **No dedicated account-deletion API was found in the inspected auth routes:** provide a real deletion path and in-app UI before App Store release, subject to current applicable App Store policies.
- **Backend owns complicated lifecycle decisions:** reminder recalculation, date conversion, family authorization, AI processing and AI confidence should not be reimplemented independently on iOS.
- **Main dashboard is comparatively large:** avoid porting its monolithic view/controller structure; build small screens and feature-specific view models.
- **Existing API has useful starting points:** manually created items via POST `/items` and a timeline endpoint mean the first useful iOS release does not depend on AI.

## 3. Product and architectural boundaries

### 3.1 System responsibilities

| Responsibility | Native iOS client | Existing backend |
| --- | --- | --- |
| Forms, screen navigation, accessibility, adaptive layouts | Owner | Not applicable |
| User intent, presentation state, temporary drafts | Owner | Not applicable |
| Authentication UI and session handling | Coordinates | Validates session and identity |
| Authoritative item, capture, reminder and family records | Caches/displays | Owner |
| AI understanding and cost/secret management | Requests and displays results | Owner |
| Business status transitions and reminder schedules | Invokes defined use cases | Authoritative validation and mutation |
| Timezone display, date entry and locale formatting | Owner of UI formatting | Owner of persisted time interpretation |
| Device-local notification permission, navigation and in-app badge | Owner | Stores preferences and sends real pushes when implemented |
| Data-access permission checks | Defensive UI only | Authoritative, mandatory |
| Offline queued changes | Optional later | Resolves conflicts and validates writes |

### 3.2 Preferred architecture

Use **MVVM inside each presentation module** and **Clean Architecture between the presentation, domain and data boundaries**. A view communicates user events to a view model. A view model invokes a use case or a simple domain service. A repository protocol describes data operations; an injected concrete repository uses URLSession and decoding. The app's composition root creates the implementations. Domain types are not SwiftUI types, JSON DTOs, persistence models or dependency-container instances.

**Dependency rule:** The business domain does not import SwiftUI, URLSession, specific SDKs or persistence packages. Feature presentation may import its own domain contracts plus the design system. Infrastructure implements domain interfaces. The composition root can see and wire everything; feature modules must not directly construct infrastructure or each other.

**Right-size the layers:** For a simple read-only preference toggle, a view model can call a repository protocol directly when a dedicated use case would add no meaningful policy. Introduce a use case when there is a meaningful rule, orchestration, reuse, authorization condition or complex error handling. Do not create one file/protocol per method purely for appearances.

### 3.3 Module and package strategy

Start with a single Xcode application target plus a small number of local SPM packages. Package boundaries should follow stable responsibilities, not every Swift file or every screen.

| Group | Suggested target/module | Responsibility | Initial phase |
| --- | --- | --- | --- |
| Application | LifeLoopApp | Entry point, dependency composition, routing, app lifecycle | 0 |
| Shared | LifeLoopDomain | Pure shared entities, IDs, errors, repository contracts, value types | 0 |
| Shared | LifeLoopNetworking | URLSession client, cookie/session behavior, decoding and HTTP errors | 1 |
| Shared | LifeLoopDesignSystem | Typography, spacing, reusable controls, accessibility patterns | 1 |
| Shared | LifeLoopTesting | Test fixtures, fakes, deterministic clock/network helpers | 1 |
| Feature | AuthFeature | Authentication and account lifecycle screens | 1 |
| Feature | ItemsFeature | Manual item CRUD, detail, edit, completion and snooze | 2 |
| Feature | DashboardFeature | Priority, Timeline and read models | 2 |
| Feature | CaptureFeature | Text and media capture, processing and retry UI | 3 |
| Feature | RemindersFeature | Reminder management, notification preferences and later push bridge | 4 |
| Feature | WaitingForFeature | Waiting For workflows; can stay an Items subfolder initially | 6 |
| Feature | MediaFeature | Camera, Photos, document picker, upload handling | 7 |
| Shared infrastructure | LifeLoopLocalStore | Persisted drafts, read cache and later outbox | 8 |
| Feature | FamilyFeature | Membership, invitations, sharing, family notifications | 9 |
| Feature | IntelligenceFeature | Ask My Life; graph as a separate advanced subfeature if needed | 11 |

**Do not create all feature targets on day one.** Create a package only when it has a real consumer and an independently testable responsibility. Keep feature-internal `Presentation`, `Domain` and `Data` groupings where useful. One central repository API implementation can serve several small features initially, but do not let a global networking manager absorb business rules.

### 3.4 Design principles to enforce

- **Single Responsibility:** screen views render; view models coordinate; use cases express rules; repositories retrieve/persist; mappers convert wire data.
- **Open/Closed:** support new item variants using targeted domain rules and reusable item rendering, rather than growing one massive switch-driven dashboard.
- **Liskov Substitution:** a fake repository and a live repository must obey the same contracts including failure behavior and cancellation.
- **Interface Segregation:** prefer small, feature-relevant repository protocols to an all-purpose `LifeLoopService` interface.
- **Dependency Inversion:** feature code depends on contracts; application composition supplies concrete networking, clocks, local stores and notification implementations.

**Swift concurrency rule:** UI-observable view models should update state on the main actor. Shared mutable managers should use appropriate isolation (actors when warranted), Sendable-safe data and structured cancellation. Avoid uncontrolled detached tasks and do not hide thread-safety problems behind blanket `@unchecked Sendable`.

## 4. Non-negotiable domain and API contract decisions

Before implementing screens, document exact request/response contracts from the running backend. In particular:

1. **IDs:** preserve server UUIDs; no device-generated replacement for persisted server entities.
2. **Item types:** distinguish `task`, `payment`, `renewal`, `appointment`, `subscription`, `waiting_for`, `document`, `vehicle` and other server-supported types. Unknown future types must degrade gracefully.
3. **Item statuses:** include server states such as `pending_review`, `active`, `completed`, `snoozed` and `archived`; capture processing has a separate state machine (`pending`, `processing`, `completed`, `failed`, `fallback_pending_retry`). Never conflate them.
4. **Metadata:** server `metadata` is flexible JSON containing amount, currency, vendor, waiting person and inferred fields. Expose typed access for fields the UI needs; preserve unknown fields on read and avoid replacing fields unintentionally on edit.
5. **Dates:** represent instants and date-only intentions separately in the domain. Respect `hasExplicitTime`, selected IANA time zone, locale and daylight-saving transitions. Document how the backend currently interprets dates; do not silently change semantics on iOS.
6. **Confidence:** AI output may need review. Distinguish `pending_review` from overdue; an unconfirmed task due tomorrow is not an overdue task.
7. **Auth:** retain cookie-based session behavior unless a formal backend architecture decision changes it. Handle 401 session expiry and 403 account/permission restrictions distinctly.
8. **Error model:** normalize transport, timeout, offline, unauthorized, validation, conflict, rate-limit and server failures into user-safe, localized presentation messages.
9. **Mutations:** define idempotency/duplicate-submission behavior before offline queues, retries and double-tap protection. Do not automatically retry non-idempotent writes without safety guarantees.
10. **Family permissions:** sharing is not ownership; server access revocation must win over any local cached value.

**Contract artifacts required:** OpenAPI-style endpoint inventory; example success/error payloads; authenticated vs privileged endpoint matrix; DTO-to-domain mapping inventory; server/client responsibility ledger; schema evolution and backward-compatibility policy.

## 5. Release train overview

All phases end with a tagged build, a regression run, a changelog and a recorded go/no-go. TestFlight is the default rollout channel until public release readiness is achieved.

| Phase | Release | Deliverable | Audience |
| --- | --- | --- | --- |
| 0 | R0.0 | Compiling native shell, documented contracts and CI baseline | Developer/internal |
| 1 | R0.1 | Secure login, session restoration, account state and navigation | Internal TestFlight |
| 2 | R0.2 | Manual tasks/items, Priority and Timeline: first end-to-end utility | Small TestFlight |
| 3 | R0.3 | Text capture and AI processing/review | Small TestFlight |
| 4 | R0.4 | Reliable reminder UX, recurrence/snooze and notification options | TestFlight |
| 5 | R1.0 candidate | Account/privacy, accessibility, reliability, Apple distribution readiness | Public only if gates pass |
| 6 | R1.1 | Rich item types and Waiting For | Public staged release |
| 7 | R1.2 | Image/document capture, secure attachments, photo permissions | Public staged release |
| 8 | R1.3 | Persistent offline cache, queued writes, sync reconciliation | Public staged release |
| 9 | R1.4 | Family groups, invitations and controlled sharing | Public staged release |
| 10 | R1.5 | Native integrations: widgets, Shortcuts, share sheet, calendar | Public staged release |
| 11 | R2.0 optional | Ask My Life and Knowledge Graph, after authorization/product validation | Opt-in/staged |

**Sequencing caveat:** Real APNs delivery or dependable local reminders should be part of Phase 4 acceptance if the product promises timely notifications. If the push backend is not ready, narrow the Phase 4/public release promise rather than marking notifications complete. Similarly, Phase 5 can move earlier if the initial public release has fewer features; privacy and reliability requirements never move later than public availability.

## 6. Phase-by-phase execution plan

### PHASE 0 — Product audit, architecture baseline and engineering setup (R0.0)

**User value:** No public feature yet. This phase prevents expensive architectural rework.

**Scope:** Record current web behavior by walking critical journeys. Inventory backend endpoints, request/response bodies, session cookies, error formats, item types, statuses, existing test scenarios and feature entitlements. Decide a supported iOS deployment target and Xcode version compatible with devices you intend to support. Choose a deployment topology for the existing backend; separate development, staging and production. Create the iOS repository/project, initial build schemes, app identifiers, signing, preview assets and basic CI. Decide what stays in the shared web backend and what must be added for mobile. Establish the feature parity matrix.

**Steps:** (1) Establish requirements and source-of-truth documents. (2) Walk web journeys: sign up, create item, capture text, process AI, mark complete, snooze, reminder, family invite. (3) Capture anonymized API examples. (4) Draft bounded contexts and dependency rules. (5) Set up project/schemes/test targets and staging credentials. (6) Create architectural decision records (ADRs). (7) Validate a build on one iPhone simulator and one iPad simulator. (8) Tag the baseline.

**Learn:** Xcode project structure, targets vs SPM products, application lifecycle, Swift access control, module visibility, Apple signing, basic CI and dependency graphs.

**Tests/gate:** Empty application launches on both device classes; all schemes build; test target executes; no secrets in repository; basic CI succeeds; all backend endpoints used by Phase 1 have sample fixtures; decisions are signed off.

**Out of scope:** Feature UI, persistence frameworks, AI SDK integration and remote push.

### PHASE 1 — App shell and authenticated session (R0.1)

**User value:** Users can securely sign in and arrive at a native authenticated home screen.

**Scope:** App routing, loading/signed-out/verified/unverified states, email-password login, logout, session restoration, `/auth/me`, verification flow and structured error presentation. Implement registration/verification only if the backend flow can be opened and completed safely from the device. Google Sign-In is optional at this stage; if added, verify token audience/client IDs against backend requirements. Evaluate Sign in with Apple and current App Review rules before adding social login for public release. Implement secure cookie handling with URLSession; do not invent a bearer-token refresh mechanism.

**Steps:** (1) Define auth domain states. (2) Build repository contract and session-aware URLSession client. (3) Build login and authentication view model. (4) Implement app coordinator and route guards. (5) Handle 401, 403, verification, expired session and server outages. (6) Verify cookie persistence and logout behavior on an actual device. (7) Add credential-sensitive logging protections and tests. (8) Release R0.1.

**Learn:** SwiftUI `@State`/`@Binding`/observable view models, `@MainActor`, async/await, protocol DI, URLSession configuration, cookie storage, HTTP semantics, Keychain vs cookies, cancellation, basic accessibility.

**Tests/gate:** Valid/invalid login; no auto-account creation on failed login; verified/unverified state; app relaunch; background/foreground; missing/expired session; logout; offline login handling; no password/session values in logs; proper iPad layout.

**Out of scope:** Family, AI, task list, biometric lock, token refresh and advanced settings.

### PHASE 2 — Manual items, Priority and Timeline: first usable MVP (R0.2)

**User value:** A person can create a task or deadline, view it, edit it, complete it and see it grouped by date.

**Scope:** `GET/POST/PATCH/DELETE /api/v1/items`, item details, completion, snooze, Priority view and Timeline view, list refresh, search/filter only if manageable. Use native form controls and consistent loading/empty/error states. Start with task, appointment and renewal only where actual backend item fields support the UI; leave sophisticated custom metadata screens for Phase 6.

**Steps:** (1) Define typed item/domain models and DTO mapping. (2) Build shared date formatting and clock injection. (3) Implement Items repository and use cases. (4) Build item form, detail and small reusable item row/card. (5) Build Priority and Timeline using a single consistent grouping policy. (6) Verify server timeline rules against web fixtures; decide whether to consume `/items/timeline` or map server items locally for rendering, without conflicting business rules. (7) Implement state restoration/refresh and destructive-action confirmation. (8) Release R0.2 to a handful of testers.

**Learn:** `List`, `NavigationStack`, `NavigationSplitView`, adaptive iPad layouts, `Date` vs `DateComponents`, locales, `Codable`, generic network errors, test doubles, view-model tests and SwiftUI previews.

**Tests/gate:** Create/edit/delete/complete/snooze; Today/Tomorrow/This Week/Upcoming/Overdue grouping; no-date item; pending review not mislabeled overdue; multiple time zones; failed write preserves draft; empty state; VoiceOver labels and Dynamic Type; iPhone/iPad acceptance journeys.

**Out of scope:** AI capture, remote notifications, documents and family sharing.

### PHASE 3 — Text capture and server AI processing (R0.3)

**User value:** Type a natural-language reminder or thought; LifeLoop organizes it into reviewable structured items.

**Scope:** `POST /captures` with `source=ios`, processing history, capture statuses, new parsed items, retry flow, AI confidence and explicit human review/approval/edit. Use the existing server Gemini integration and do not put any Gemini API key in the application. Initially use foreground refresh/polling; stop polling when work settles, and add backoff and cancellation. The server may return a created capture before AI processing finishes.

**Steps:** (1) Design text capture and capture state domain models. (2) Build short capture composer and capture history. (3) Send correct user time zone header and identity/source metadata. (4) Implement processing state UI: pending, processing, completed, fallback pending retry, failed. (5) Fetch newly extracted items and surface review. (6) Support safe retry and distinguish AI suggestion from user-verified data. (7) Test process cancellation and app leaving foreground. (8) Release R0.3.

**Learn:** Multipart requests, async workflows, polling with backoff, state machines, task cancellation, resilient UI, AI extraction uncertainty, separation of server AI from mobile presentation.

**Tests/gate:** Multiple items extracted from one sentence; relative-date interpretations; malformed/empty AI output; slow and timed-out processing; repeated taps; fallback and retry; no unintended duplicates; pending-review preserved; data isolation and secret protection.

**Out of scope:** Voice, PDFs, direct on-device AI, Ask My Life and advanced entity graphs.

### PHASE 4 — Reminders and notification reliability (R0.4)

**User value:** A user can set and manage useful reminders and receive clear, trustworthy notification behavior.

**Scope:** Reminder list/detail, absolute and relative triggers, presets, recurrence, edit, snooze, cancellation, settings for quiet hours and delivery channels, device permission UX and notification-to-item navigation. Decide an explicit delivery design: (A) server-owned remote notifications through real APNs, or (B) device-local scheduled notifications with a documented reconciliation strategy. A hybrid can follow, but must prevent duplicate alerts.

**Backend blocker:** Current iOS provider only fabricates a delivery-success result. Before claiming remote push works, add authenticated device-token registration/rotation/revocation, APNs credentials, real sending, delivery failure handling, user/device routing and sensible idempotency. Push delivery itself is best-effort; do not promise guaranteed exact-time delivery. Avoid blanket time-sensitive interruption levels: use them only when justified by user intent and Apple guidance.

**Steps:** (1) Map reminder lifecycle and backend source-of-truth rules. (2) Implement reminder models/use cases/views. (3) Add explicit permission explanation and status UI. (4) Validate server and device scheduling ownership. (5) Connect real push or limited local notifications. (6) Handle notification actions/deep links and disabled permissions. (7) Test recurrence, DST, time-zone changes and reminder updates. (8) Release R0.4 only after the stated notification promise is observed on a real device.

**Learn:** UserNotifications, APNs versus local notifications, app background constraints, recurrence date math, IANA time zones, DST, notification privacy, deep links, idempotency and reliability testing.

**Tests/gate:** Notification received on physical iPhone in supported mode; app killed/locked; permission denied; changed due date reschedules; completion/delete cancels pending alerts; snooze; duplication prevention across devices and channels; quiet hours; DST transitions; timezone travel; offline expectations documented.

**Out of scope:** Widgets, family-assigned reminders and sophisticated calendar integration.

### PHASE 5 — Public-launch foundation and first App Store candidate (R1.0)

**User value:** A trustworthy first public release of core life organization, rather than an overloaded beta.

**Scope:** Privacy policy, terms if needed, account deletion and data deletion/export approach, onboarding, permission copy, app metadata, screenshots, release notes, error monitoring, backend availability, rate-limit behavior, accessibility, localization readiness and performance. Conduct a security review of session handling and endpoints; no confidential data in analytics or logs. Evaluate Apple review requirements current at submission time.

**Steps:** (1) Implement missing account-deletion backend workflow and app UI; provide confirmation and clear irreversible consequences. (2) Review privacy/attachment access. (3) Validate App Store login/account rules, SDK disclosure and any third-party sign-in requirements. (4) Add production monitoring without sensitive payloads. (5) Run end-to-end failure-mode tests and accessibility audits. (6) Prepare TestFlight external feedback, staged rollout and rollback plan. (7) Submit only after all gates pass.

**Learn:** App Store Connect, privacy manifests and permissions, app lifecycle, energy diagnostics, Instruments, Accessibility Inspector, TestFlight, crash symbolication, release pipelines and risk review.

**Tests/gate:** Account creation/login and deletion functional; no orphaned personal data outside documented retention rules; TLS-only backend; authorization isolation; acceptable startup and scrolling performance on an older supported iPhone and a large iPad; VoiceOver, large type, reduced motion; privacy disclosures verified; no blocker crashes in test group; documented rollback.

**Out of scope:** Parity with all web features. **Release rule:** If any blocker remains, maintain TestFlight only and do not label this a public 1.0.

### PHASE 6 — Rich item types, Waiting For and lifecycle polish (R1.1)

**User value:** Track payments, insurance renewals, subscriptions, appointments, purchases and things expected from other people—not just generic tasks.

**Scope:** Type-specific details and validations, money/currency formatting, vendor/person fields, expected reply dates, status changes, category-aware cards and filtering. Treat Waiting For as a particular item workflow unless real complexity warrants a distinct package. Keep unfamiliar metadata safe, and do not infer a new database schema for each type without evidence.

**Steps:** (1) Create a capability matrix by item type. (2) Build reusable field definitions and validation where they improve usability. (3) Implement Waiting For list and state transitions. (4) Support details, dates, amounts and safe editing without dropping unknown metadata. (5) Add lifecycle tests and analytics focused on usefulness, not sensitive content. (6) Release R1.1.

**Learn:** Domain modeling, value objects, validation, enums with unknown server values, currencies and locales, SwiftUI form composition, schema evolution and SOLID in real features.

**Tests/gate:** Multiple currencies; date-only renewals; waiting received/cancelled; unknown item types; incorrect input and server validation; no unintended metadata loss; existing task flows unaffected.

### PHASE 7 — Images, photos and private documents (R1.2)

**User value:** Capture a receipt, insurance document or photo and access it securely later.

**Scope:** PhotosPicker, camera access only when necessary, document picker, safe multipart upload, progress, cancellation, retry, media preview and server processing states. First audit and fix how private uploads are stored and served. Define file size limits and accepted MIME types from the backend. Avoid promising PDF text extraction/audio transcription until server support is confirmed.

**Steps:** (1) Security review media storage and download authorization. (2) Define file ownership, delete and retention behavior. (3) Implement system photo/document pickers and file metadata display. (4) Transfer with progress and sensible memory usage. (5) Render secured preview/download. (6) Validate processing, failed upload and account removal cleanup. (7) Release R1.2.

**Learn:** PhotosUI, UIDocumentPicker, security-scoped URLs, URLSession upload, large-file memory management, MIME types, image downsampling, file protection and permission UX.

**Tests/gate:** Private media inaccessible across users and without auth; oversized/unsupported files; damaged/partial uploads; interrupted network; limited-photo permissions; background/relaunch behavior; orphan file cleanup; memory and storage constraints; correct deletion.

**Out of scope:** Voice transcription and advanced PDF/OCR unless backend-specific milestones are added.

### PHASE 8 — Offline-read, durable drafts and synchronization (R1.3)

**User value:** Read recent tasks without a connection and safely capture edits to synchronize later.

**Scope:** Local persistence of selected user-visible data; draft and mutation outbox; sync queue with per-operation IDs, explicit pending/conflict state and reconciliation on reconnect. Use SwiftData or another local store only after testing fit for schema migration and concurrency. Do not sync secrets or unprotected family content. Start offline with tasks and captures; expand gradually to reminders/family after conflict rules are proven.

**Steps:** (1) Record offline product guarantees. (2) Design local cache, ownership boundaries and data retention. (3) Add read cache and reliable drafts. (4) Introduce an outbox for chosen idempotent or idempotency-protected writes. (5) Define conflict resolution by operation, server revision/time and permissions. (6) Reconcile after reconnect; add SSE/polling only as a freshness trigger. (7) Test migration, logout and user-switch cleanup. (8) Release R1.3.

**Learn:** SwiftData/Core Data tradeoffs, local encryption/file protection, outbox pattern, optimistic UI, eventual consistency, sync tokens, idempotency, actor isolation and deterministic chaos tests.

**Tests/gate:** Airplane mode, network loss mid-write, duplicate retries, reordered updates, app terminated, two devices edit same item, family access revoked, server refuses outdated changes, no cross-account cache leak, data migrations recover safely.

**Out of scope:** Full offline replication of the entire LifeLoop database.

### PHASE 9 — Family, invitations and permissions (R1.4)

**User value:** Invite family members, share selected responsibilities and preserve private-by-default behavior.

**Scope:** Family creation, invite/accept/reject, membership roles, share/unshare items, shared collection, family notifications and appropriate navigation. Server role and ownership checks remain authoritative. Implement universal links for invites and sign-in return path. Guard cached/shared data after revocation.

**Steps:** (1) Document exact role matrix: owner/admin/member/view-only. (2) Add family domain/repository and route handling. (3) Build membership, invitation and shared-item workflows. (4) Surface sharing permissions plainly. (5) Test invite expiry and cross-account behavior. (6) Build revoked-access cache invalidation and conflict behavior. (7) Release R1.4.

**Learn:** Authorization vs authentication, deep/universal links, state synchronization, role-based access control, multi-tenant privacy, multi-device testing and feature integration through protocols.

**Tests/gate:** Wrong recipient cannot accept invite; expired invite; role changes; member removal; owner-only deletion; explicit sharing/unsharing; view-only mutation denied; immediate access revocation even from stale offline cache; no accidental family-visible items.

### PHASE 10 — Native ecosystem enhancements (R1.5)

**User value:** Capture and see LifeLoop information more conveniently throughout iOS and iPadOS.

**Scope:** Choose **one** highest-value integration at a time: Home Screen widget, App Intents/Shortcuts, share sheet, notification actions, then Calendar integration if user value warrants it. iPad multitasking, keyboard commands and accessibility can be enhanced throughout the roadmap rather than saved for this phase. Only integrate Calendar with explicit permission and duplicate-event policy.

**Steps:** (1) Use real user feedback to rank integrations. (2) Design a narrow, versioned shared data boundary. (3) Build one integration and its privacy model. (4) Add deep link state restoration and tests. (5) Release, measure, then decide the next enhancement.

**Learn:** WidgetKit, App Intents, app groups where justified, extension security, EventKit, Shortcuts and platform lifecycle restrictions.

**Tests/gate:** Widget displays current permitted data; no sensitive information on locked devices without user choice; extension works when app is unavailable; deep links recover authentication and routing; no duplicate Calendar events.

### PHASE 11 — Ask My Life, Knowledge Graph and product experiments (R2.0, optional)

**User value:** Explore and query previously captured life information with grounded, permission-controlled answers.

**Scope:** Ask My Life backed by the existing `/ask` service and relation graph if these become user-facing features. The web currently gates them for administrators; mobile must respect the same backend entitlement and must not bypass it. Validate product demand, operating cost, prompt-injection protections and citations before broad release. Consider premium/feature flag policy only after product experiments.

**Steps:** (1) Decide whether Ask/Graph should be enabled for regular users. (2) Implement server-side authorization/entitlement rules and feature flag. (3) Build a modest citation-first chat UX. (4) Ensure answers link to authorized, current items. (5) Add graph only if it helps users complete concrete tasks. (6) Roll out to opt-in group and assess value.

**Learn:** RAG grounding, retrieval permissions, inference economics, hallucination evaluation, data exposure tests, safe prompt handling, feature flags and measured product experiments.

**Tests/gate:** No cross-user/family leakage; untrusted stored text cannot override system policy; supported citations resolve; unknown questions return uncertainty; disabled entitlement stays blocked; cost budgets and latency defined; opt-in users report useful outcomes.

## 7. User experience, navigation and adaptation

**First releases:** On iPhone, use a small native tab structure centered on Priority, Timeline and Inbox/Capture, with Profile/Settings in a predictable location. Avoid placing all six web sections into first-release navigation. The primary Capture action should be reachable without navigating a complex menu. On iPad, use sidebar or split-view patterns when they improve browse/detail workflows. Keep user task terminology consistent with the web backend, but use platform-appropriate gestures, sheets and controls.

**Required UI states for each feature:** loading, success/content, empty, offline, recoverable error, permission-denied, session-expired and destructive-action confirmation. For multi-step capture workflows also include submitting, processing, fallback/review and retry.

**Accessibility baseline:** Dynamic Type, VoiceOver semantics, contrast, sensible tap targets, non-color-only status, reduced-motion support and hardware keyboard navigation on iPad. Accessibility tests start in Phase 1 rather than being deferred to public launch.

## 8. Quality strategy, test pyramid and Definition of Done

**Domain/unit:** Test mapping, grouping, date-only vs instant semantics, state machines, validation and use-case behavior with injected clock and fake repository. **Integration/contract:** Use staging backend against real auth, item, capture, reminder and family APIs; verify HTTP errors and schema evolution. **UI:** Small deterministic UI tests for login, task creation, capture, reminder and family invite. **Real device:** Run notifications, backgrounding, camera/files, large-text VoiceOver and network-transition checks on real devices.

A feature is **Done** only when: (1) its user journey works on iPhone and iPad; (2) the domain boundary and API contract are documented; (3) loading/empty/error/unauthorized states are handled; (4) unit, contract and UI tests relevant to risk pass; (5) secrets and sensitive data are protected; (6) VoiceOver and Dynamic Type are checked; (7) analytics are privacy-safe; (8) the TestFlight build is tagged and release notes exist; (9) there are no unresolved release-blocking defects; and (10) the learning note and architectural decision log are updated.

**Suggested thresholds, not arbitrary release absolutes:** Set a coverage target for critical domain paths (for example 85–90%) and prioritize meaningful behavior over line coverage. Define crash-free rate, cold-start time, response performance and supported-device budgets based on measured baseline rather than invented numbers.

## 9. Backend workstream and blockers

These are mobile-enabling backend tasks; keep them as separately managed tickets. Not every change needs to be completed at Phase 0.

| Priority | Task | Why it matters | Required by |
| --- | --- | --- | --- |
| P0 | Verify backend environment URLs, staging isolation, HTTPS, account roles | Avoid production data damage and auth failures | Phase 0–1 |
| P0 | Publish API contract examples and error schemas | Prevent client/server drift | Phase 1–2 |
| P0 | Review cookie attributes and native mobile session persistence | Current API expects HTTP-only cookie | Phase 1 |
| P0 | Provide reliable account deletion/data lifecycle | Public release privacy/account requirement | Phase 5 |
| P0 | Audit public `/uploads` and implement private access as necessary | Uploaded sensitive documents may be exposed | Phase 7, earlier if sensitive captures released |
| P0 | Replace fake APNs “delivered” provider with real transport or narrow feature promise | Notification reliability and truthfulness | Phase 4/public |
| P1 | Implement device token registration/rotation and device logout cleanup | Real multi-device push routing | Phase 4 |
| P1 | Idempotent mutation contract, version/conflict semantics | Safe retry and offline sync | Phase 8 |
| P1 | Robust processing watchdog and retry reconciliation | Avoid captures stranded after server restarts | Phase 3 maturity |
| P1 | API compatibility/versioning, pagination if lists grow | Scaling without broad client breakage | Phase 2 onward |
| P1 | SSE event replay/scaling or reconciliation strategy | Multi-instance and disconnected refresh | Phase 8 |
| P1 | Universal-link invitation behavior | Family invite completion | Phase 9 |
| P2 | PDF extraction, voice transcription | Optional future captures | New scoped phase |
| P2 | Standard-user Ask/Graph entitlement policy | Do not expose admin-only features accidentally | Phase 11 |

## 10. Engineering workflow to repeat in every phase

1. **Select one user outcome:** write a one-sentence story and acceptance criteria. Avoid batching unrelated features.
2. **Trace the existing source:** identify UI reference, backend route, model, statuses and server tests. Capture a real sample request and response from staging.
3. **Design before implementation:** sketch flow and UI state diagram; identify bounded context and repository contract. Decide if any new package/use case is justified.
4. **Write the learning brief:** list Swift/iOS concepts to explore, questions to answer and a tiny isolated prototype if necessary.
5. **Implement vertical slices:** connect domain mapping → repository → view model → view; do not build every layer for all future features up front.
6. **Validate continuously:** start with deterministic unit tests and previews; then staging integration; then simulator and device UI journeys.
7. **Review architecture:** inspect dependencies, SOLID, concurrency, data ownership, cancellation, user-facing errors, privacy and testability.
8. **Release:** merge to main, run CI, tag build, distribute to TestFlight testers, collect feedback and record known limitations.
9. **Learn and improve:** write a phase retrospective: what was learned, what should remain stable, what must be refactored next, and what not to prematurely optimize.

**AI coding assistant policy:** Use an AI assistant as an explainer, reviewer and debugging partner. Require the assistant to explain architecture and tradeoffs before making changes; ask it to work on one phase/ticket at a time, preserve existing contracts, and run tests. Review generated changes yourself. Do not let a tool independently rebuild the full app from this roadmap.

## 11. Governance and living documentation

Maintain a small set of source-of-truth documents, reviewed after each release:

- **Master Blueprint (this document):** purpose, architecture principles, roadmap and release gates; stable, revision-controlled.
- **Architecture Decision Records (ADRs):** decision, date, alternatives, rationale, consequences and revisit trigger. Initial ADRs: native SwiftUI, MVVM/Clean, backend reuse, cookie auth, local persistence and notification strategy.
- **API Contract and Parity Matrix:** endpoint, auth role, payload, backend owner, UI owner, tests, implemented iOS version.
- **Release Backlog:** small tickets with user-visible acceptance criteria, dependency and release number.
- **Test Matrix:** unit/integration/UI/device/privacy cases with status and evidence.
- **Release Notes/Decision Log:** what shipped, known limitations and rollback actions.
- **Learning Journal:** key concepts learned, experiments run, questions answered and resources used.

**Change control:** A new requirement may alter phase order, but not the dependency direction, security gates, data ownership or test expectations without an ADR. A feature is not moved to “done” simply because a view renders; it must have tested end-to-end behavior with real contracts.

## 12. First actionable sprint: start here

**Sprint goal:** Phase 0 complete and first Phase 1 authentication vertical slice demonstrable.

1. Freeze this document at version 1.0 and create an iOS development issue board organized by release.
2. Run and verify the existing web app/backend against a dedicated development environment; do not connect test builds to the production database.
3. Record precise API responses for `/auth/login`, `/auth/me`, `/auth/logout`, `/items`, `/captures` and their error cases.
4. Create the native Xcode application, iPhone+iPad targets/scene adaptation, schemes and minimal CI.
5. Add only the shared Domain, Networking and Design System boundaries required by login.
6. Build the login → session check → authenticated home → logout journey.
7. Test relaunch, invalid credentials, verification-required, unauthorized, poor network and iPad layout.
8. Publish R0.1 to a small internal TestFlight group only when the corresponding gate passes.

**Do not start with:** AI chat, database reimplementation, offline synchronization engine, many generic base view models, every item type, all six web tabs or an elaborate package graph. These are the most likely sources of unnecessary complexity before the first valuable release.

## 13. Reference anchors inspected

- Main repository: https://github.com/elangbamjohnson/LifeLoop
- Readme: https://github.com/elangbamjohnson/LifeLoop/blob/main/README.md
- Source architecture: https://github.com/elangbamjohnson/LifeLoop/blob/main/ARCHITECTURE.md
- HTTP router registration: https://github.com/elangbamjohnson/LifeLoop/blob/main/src/server/app.ts
- Auth and cookie endpoints: https://github.com/elangbamjohnson/LifeLoop/blob/main/src/server/api/v1/auth.ts
- Database tables: https://github.com/elangbamjohnson/LifeLoop/blob/main/src/db/schema.ts
- Captures: https://github.com/elangbamjohnson/LifeLoop/blob/main/src/server/api/v1/captures.ts
- Items: https://github.com/elangbamjohnson/LifeLoop/blob/main/src/server/api/v1/items.ts
- Reminders: https://github.com/elangbamjohnson/LifeLoop/blob/main/src/server/api/v1/reminders.ts
- Notification provider: https://github.com/elangbamjohnson/LifeLoop/blob/main/src/server/services/NotificationProvider.ts
- Family API: https://github.com/elangbamjohnson/LifeLoop/blob/main/src/server/api/v1/families.ts
- AI service: https://github.com/elangbamjohnson/LifeLoop/blob/main/src/server/services/AIProvider.ts
- Timeline utility: https://github.com/elangbamjohnson/LifeLoop/blob/main/src/shared/utils/timeline.ts
- Historical QA snapshot (not a fresh run): https://github.com/elangbamjohnson/LifeLoop/blob/main/QA_READINESS_VERDICT.md

---

**Standing principle:** **Build one reliable user outcome, learn why its design works, release it, then extend.** Protect the domain boundaries and the user's data before optimizing for a future scale that has not yet arrived.
