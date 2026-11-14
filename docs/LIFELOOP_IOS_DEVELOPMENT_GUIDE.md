# LifeLoop for iPhone and iPad — Development Guide

**Document version:** 1.0  
**Prepared:** 14 November 2026  
**Audience:** An iOS developer learning through the design, implementation, and release of LifeLoop  
**Status:** Proposed development baseline; implementation has not started in this workspace  
**Scope:** Instructions, architecture, learning objectives, acceptance criteria, and rollout planning. No application code.

## 1. Project mandate and how to use this guide

Build a native LifeLoop app for iPhone and iPad that uses the **same accounts, backend, and personal data as the web application from its first public release**. Learn the technologies and engineering decisions as each feature creates a reason to use them.

You have already built iOS apps. This plan therefore emphasizes modern state management, architectural boundaries, concurrency, API integration, data integrity, native platform behavior, and operating releases. Revisit Swift syntax or introductory UI material only when a specific gap blocks the current phase.

The product's core loop is:

**Capture something → preserve the original → extract useful items → review or correct them → organize and act → return with confidence that the data is still there.**

The recommended architecture is **SwiftUI with feature-oriented MVVM and proportionate Clean Architecture boundaries**. Keep the existing Express/PostgreSQL system as the shared authority. Use a modular monolith on both sides until measured needs justify more separation.

Work on one release slice at a time. Finish its acceptance criteria, distribute it, review feedback, and record the outcome before adding the next major capability. A foundation phase ends in a review or internal TestFlight build; a useful, complete product increment ends in an App Store release. Setup work does not need its own public release.

Treat this guide as the project's maintained source of decisions, rather than an immutable specification. At the start of each phase, verify its assumptions against the current backend and Apple requirements. Update the decision log when evidence changes a recommendation. Never silently change a previously shipped behavior.

### Navigation

- [Repository findings](#2-what-the-web-project-actually-contains)
- [Technology and architecture decisions](#3-technology-and-architecture-decisions)
- [Modules and SOLID](#4-module-boundaries-and-solid)
- [Data and API contracts](#5-contracts-to-settle-before-building-features)
- [Release map](#6-release-map)
- [Phase-by-phase instructions](#7-phase-by-phase-instructions)
- [Quality and rollout gates](#8-quality-and-rollout-gates)
- [Working and learning process](#9-working-and-learning-process)
- [Decision and risk register](#10-decision-and-risk-register)
- [First working session](#11-your-first-working-session)

## 2. What the web project actually contains

### Inspection baseline and limits

The reference is [elangbamjohnson/LifeLoop](https://github.com/elangbamjohnson/LifeLoop), default branch `main`, inspected at commit [1e268acc](https://github.com/elangbamjohnson/LifeLoop/commit/1e268acccac2a8a644a27e243801ddc94bba8f65). This was a static inspection of source, configuration, schemas, tests, and repository documents. The application and tests were not run, and production deployment settings were not verified. The repository's historical passing-test reports are not evidence of a fresh passing run.

The local LifeLoop-iOS workspace was empty at inspection. Xcode 26.6 was installed. That is an environment observation, not a requirement to remain on that version throughout development.

The web stack contains React/TypeScript/Vite, an Express API, PostgreSQL with Drizzle, Gemini integration, Vitest, and Playwright. Reuse the API and server capabilities after validating them; build native presentation and platform integrations. See the [package manifest](https://github.com/elangbamjohnson/LifeLoop/blob/1e268acccac2a8a644a27e243801ddc94bba8f65/package.json).

### Feature inventory and proposed treatment

| Area | Source inspection finding | Native treatment |
| --- | --- | --- |
| Accounts | Email/password, Google login, email verification, resend, change unverified email, logout | Existing account identity is a launch requirement; add missing lifecycle capabilities |
| Text capture | Stores raw input and processes asynchronously; retry and fallback states exist | Defining first-public-release capability |
| Review and items | Confirm/edit, complete/reopen, snooze, delete; multiple types and statuses | Build a small, complete lifecycle first |
| Priority and timeline | Attention, today, tomorrow, upcoming, waiting-for, and completed groupings | Start with clear lists; expand grouping after the core release |
| Search | Client filtering of item titles, types, and metadata | Specify its scope; introduce server search with pagination |
| Reminders | Server scheduling, recurrence, quiet hours, preferences, and dispatch logic | Reuse rules after verification; real native delivery needs work |
| Calendar | Exports an ICS file and records the user's confirmation | Native one-way export later; this is not calendar synchronization |
| Waiting For | Received, snooze, and follow-up actions; follow-up opens an email draft | Separate small workflow after the core loop |
| Media capture | Admin-gated upload UI accepts images/audio/documents | Actual extraction requires separate proof and backend work |
| Life Graph | Admin-only entity directory and linked-item detail | Later entity/relationship feature; no graph visualization required |
| Ask My Life | Admin-only answers with item citations | Later, with retrieval and factuality gates |
| Family | Families, invites, roles, item sharing, in-app notification records | Existing-share compatibility first; management and collaboration later |
| Live updates | SSE invalidation plus polling/refetch | Foreground refresh first; lifecycle-aware live updates later |
| Offline behavior | PWA shell caching; API requests still need network | Native cached reads and offline mutations are additional work |

Sources: [Dashboard](https://github.com/elangbamjohnson/LifeLoop/blob/1e268acccac2a8a644a27e243801ddc94bba8f65/src/client/features/dashboard/Dashboard.tsx), [capture UI](https://github.com/elangbamjohnson/LifeLoop/blob/1e268acccac2a8a644a27e243801ddc94bba8f65/src/client/features/dashboard/CaptureDialog.tsx), [item actions](https://github.com/elangbamjohnson/LifeLoop/blob/1e268acccac2a8a644a27e243801ddc94bba8f65/src/client/features/dashboard/ItemCardActions.tsx), [family UI](https://github.com/elangbamjohnson/LifeLoop/blob/1e268acccac2a8a644a27e243801ddc94bba8f65/src/client/features/family/FamilyPage.tsx), [service worker](https://github.com/elangbamjohnson/LifeLoop/blob/1e268acccac2a8a644a27e243801ddc94bba8f65/public/sw.js).

### Findings that change the development plan

1. **The written API/domain documents lag behind implementation.** The shared types use different item fields, status values, and capture fields from the actual database/API. Establish request/response fixtures from current routes before designing Swift models. Do not translate the shared TypeScript file mechanically. Compare [shared domain types](https://github.com/elangbamjohnson/LifeLoop/blob/1e268acccac2a8a644a27e243801ddc94bba8f65/src/shared/types/domain.ts) with the [database schema](https://github.com/elangbamjohnson/LifeLoop/blob/1e268acccac2a8a644a27e243801ddc94bba8f65/src/db/schema.ts).
2. **Native push is a placeholder.** The iOS notification provider builds a payload and reports delivery without contacting APNs. A real transport, device registration, and delivery-failure handling must precede native reminder promises. See [NotificationProvider](https://github.com/elangbamjohnson/LifeLoop/blob/1e268acccac2a8a644a27e243801ddc94bba8f65/src/server/services/NotificationProvider.ts).
3. **Upload support does not establish media understanding.** The inspected Gemini path sends text containing the stored payload/URL; it does not establish a working binary image, PDF, or audio extraction pipeline. Files are stored under a publicly served uploads directory. Private storage and actual extraction are release gates. See [AIProvider](https://github.com/elangbamjohnson/LifeLoop/blob/1e268acccac2a8a644a27e243801ddc94bba8f65/src/server/services/AIProvider.ts), [storage](https://github.com/elangbamjohnson/LifeLoop/blob/1e268acccac2a8a644a27e243801ddc94bba8f65/src/server/services/StorageProvider.ts), and [server app](https://github.com/elangbamjohnson/LifeLoop/blob/1e268acccac2a8a644a27e243801ddc94bba8f65/src/server/app.ts).
4. **Authentication needs a native and public-release contract.** The current server uses a seven-day session JWT in a cookie. Google-only users can have no password. Password recovery, account deletion, and server-side session revocation are not implemented in the inspected auth router. See [authentication routes](https://github.com/elangbamjohnson/LifeLoop/blob/1e268acccac2a8a644a27e243801ddc94bba8f65/src/server/api/v1/auth.ts).
5. **Item operations already affect reminders.** Manual creation does not create reminders; editing a due date can create them. Completion cancels pending reminders, but reopening does not restore them. Settle this before native editing ships. See [item routes](https://github.com/elangbamjohnson/LifeLoop/blob/1e268acccac2a8a644a27e243801ddc94bba8f65/src/server/api/v1/items.ts) and [ReminderService](https://github.com/elangbamjohnson/LifeLoop/blob/1e268acccac2a8a644a27e243801ddc94bba8f65/src/server/services/ReminderService.ts).
6. **SSE is not a durable sync protocol.** Events invalidate client data; they do not provide a replayable change log. Foreground/reconnect reconciliation is necessary. See [EventBus](https://github.com/elangbamjohnson/LifeLoop/blob/1e268acccac2a8a644a27e243801ddc94bba8f65/src/server/services/EventBus.ts).
7. **Ask needs factuality work.** Its fallback can substitute invented defaults for absent dates/amounts, and retrieval inspects the latest 100 owned items. These behaviors must change or be explicitly constrained before a public Ask release. See [AskService](https://github.com/elangbamjohnson/LifeLoop/blob/1e268acccac2a8a644a27e243801ddc94bba8f65/src/server/services/AskService.ts).
8. **Shared editing is incomplete.** A shared item can advertise edit permission, while the ordinary item-update route still requires ownership. Do not infer supported collaborative operations from a UI badge. See [family routes](https://github.com/elangbamjohnson/LifeLoop/blob/1e268acccac2a8a644a27e243801ddc94bba8f65/src/server/api/v1/families.ts) and item routes above.

An open [Web Push pull request](https://github.com/elangbamjohnson/LifeLoop/pull/25) was also present during inspection. It is outside the inspected `main` baseline and is not evidence of native APNs support.

## 3. Technology and architecture decisions

### Why this architecture

Clean Architecture, MVVM, and VIPER are not equivalent choices at the same level. Clean Architecture defines dependency boundaries; MVVM organizes presentation. They can be used together.

| Option | Fit for LifeLoop | Decision |
| --- | --- | --- |
| SwiftUI state with direct API calls in screens | Fast for a disposable experiment, but makes lifecycle, caching, and testing harder as the app grows | Use only for isolated learning experiments |
| MVVM alone | Good screen structure; can still produce large ViewModels containing storage and business rules | Adopt with explicit boundaries |
| MVVM plus focused Clean boundaries | Separates presentation, rules, and external systems while keeping implementation approachable | **Recommended** |
| Full ceremonial Clean Architecture | Too many pass-through abstractions before they earn their cost | Introduce use cases where rules or coordination justify them |
| VIPER | Strong separation, but many roles and routing objects for each feature | Unnecessary for this solo-developed SwiftUI app |

The architecture succeeds when a change in the API payload, local database, or notification transport does not require rewriting screens or domain rules. It does not require a protocol for every type or a separate use-case object for every getter.

### Initial technology choices

| Concern | Recommended choice | Reason / revisit condition |
| --- | --- | --- |
| UI | SwiftUI; UIKit bridges for APIs that need them | Native adaptive interface and straightforward incremental development |
| Language | Swift with current concurrency checks | Learn isolation and cancellation while the codebase is small |
| Deployment minimum | Provisional iOS/iPadOS 17 | Supports Observation and SwiftData; verify actual target devices in Phase 0 |
| State observation | Observation for screen state | Keep ownership explicit; avoid a global mutable app store |
| Networking | URLSession with async/await | Sufficient for REST; add a library only for a demonstrated need |
| Local storage | SwiftData behind a local-store boundary | Account-scoped cache and drafts initially; later outbox if justified |
| Server storage | Existing PostgreSQL backend | One shared source of truth for web, iPhone, and iPad |
| Secrets | Keychain for persisted session credentials; server for provider secrets | Credentials do not belong in preferences, source control, or ordinary logs |
| Tests | Swift Testing for new unit/contract tests; XCTest/XCUIAutomation for UI journeys | Exercise rules and real integration paths at appropriate levels |
| Dependencies | Swift Package Manager | Keep third-party adoption deliberate and review maintenance/privacy impact |
| Continuous integration | GitHub Actions with a macOS runner, or Xcode Cloud if preferred | Choose one in Phase 1; automate repeatable release checks |
| Observability | Structured, redacted logs and Apple crash diagnostics first | Add an external service when the debugging benefit warrants it |

The deployment minimum and required submission SDK are separate decisions. Confirm current build requirements before every submission. Observation is available from iOS/iPadOS 17; see Apple's [model-data guidance](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app). SwiftData provides local persistence; it does not automatically synchronize the Express API. See [SwiftData](https://developer.apple.com/documentation/swiftdata).

Do not introduce CloudKit as a parallel authoritative store, a new backend platform, a dependency-injection framework, or microservices merely to prepare for hypothetical scale.

## 4. Module boundaries and SOLID

### Responsibility map

These are logical boundaries first. A folder is not an enforced module; a package or target adds compiler enforcement. Begin with feature folders inside the app target, then extract stable boundaries as described below.

| Boundary | Owns | Must not own |
| --- | --- | --- |
| App composition | Dependency construction, session-level routing, deep-link dispatch, feature availability | Item rules, API decoding, database queries |
| Design system | Typography, spacing, color, reusable controls, accessibility defaults | Networking, account state, business decisions |
| Domain | Stable value types, item/capture lifecycle rules, date semantics, capability-oriented repository interfaces | SwiftUI, URLSession, SwiftData, APNs details |
| Account | Sign-in, verification, recovery, account settings, deletion presentation | Unrelated organizer screens |
| Capture | Drafts, submission, processing state, review entry point | Direct AI-provider calls or notification delivery |
| Organizer | Item list/detail/edit, priority, timeline, scoped search, waiting-for | Authentication internals, upload implementation |
| Reminders | Reminder editing and delivery status presentation | Provider credentials or background execution assumptions |
| Knowledge | Entity relationships and, later, cited answers | Family access-control decisions |
| Family | Membership, invitations, explicit sharing, shared-item capabilities | Trusting client-only permissions |
| Data infrastructure | API DTOs, mapping, repositories, cache, reconciliation | View navigation or user-facing screen layout |
| Platform integrations | Notifications, EventKit, pickers, share extension, widgets | Duplicated core business rules |

Keep domain rules close to their owning feature. Only genuinely shared concepts belong in a common domain module. Do not turn a shared Core folder into a home for everything that is inconvenient to place.

### Dependency rules

1. A View renders state and emits intentions. It does not decide whether a server mutation is authorized or directly perform HTTP/storage operations.
2. A ViewModel owns a screen's state, coordinates operations, and translates domain results into presentation. UI-facing state is isolated appropriately to the main actor.
3. A use case owns meaningful rules or multi-step coordination, such as confirming an extracted item or reconciling a pending mutation. Simple reads may go through an injected repository without a pass-through use case.
4. Repository interfaces describe capabilities needed by the domain or feature. Data implementations depend on those interfaces and hide transport/storage details.
5. The composition root creates concrete dependencies and passes them in. Avoid service locators and globally accessible singletons.
6. Features exchange stable identifiers and domain results through app-level routing or narrow interfaces. They do not import sibling ViewModels.
7. Use distinct API DTOs, domain values, and persistence records where their contracts differ. Mapping must preserve unknown fields needed for compatibility.
8. Cancellation and account ownership travel with asynchronous work. A response started for account A must never update account B's screen or cache.

### A concrete action to trace

For “complete item,” the screen expresses the intention; the ViewModel changes to a saving state; the use case/repository submits the command; the server applies authoritative item/reminder changes; the repository maps and stores the returned state; the ViewModel renders success or a recoverable error. A failed request does not become a false success. Tests can replace the repository and clock without running the UI or contacting production.

### SOLID applied to this app

| Principle | Practical instruction | Review question |
| --- | --- | --- |
| Single responsibility | Separate capture upload, extraction-status observation, screen state, and reminder scheduling | Does this type change for unrelated reasons? |
| Open/closed | Add a new capture input or delivery adapter behind a stable boundary when a second implementation is needed | Can a new capability be added without changing unrelated screens? |
| Liskov substitution | Test doubles and implementations must honor the same error, ordering, ownership, and cancellation contract | Does the fake hide a production failure mode? |
| Interface segregation | Define small capabilities such as item reading, mutation, or notification registration | Does a consumer depend on operations it never uses? |
| Dependency inversion | Presentation and rules depend on abstractions; URLSession/SwiftData/APNs are replaceable adapters | Can domain tests run without those frameworks? |

### When to create physical modules

- **Phase 1:** Feature folders and documented dependency rules; keep the first screen-to-data path easy to follow.
- **Phase 2–3:** Extract the stable domain and design-system boundaries into local Swift packages if they are clear. Verify the domain package has no UI/network/persistence imports.
- **Later:** Extract a feature or infrastructure target when it has stable ownership, repeated reuse, independent testing needs, or costly accidental coupling. A widget/share extension is a concrete reason to extract reusable capabilities.
- **Avoid:** A package per screen, a generic repository for unrelated entities, inheritance-heavy base ViewModels, and a universal event bus carrying untyped payloads.

### How scaling should happen

Scale the client with bounded lists, paginated queries, cache policies, and measured rendering performance. Scale the backend with indexes, durable jobs, bounded AI concurrency, and shared event distribution when multiple server instances require it. Keep API compatibility with installed older app versions. Use additive migrations and expand-then-contract changes; do not remove a field the currently released app still needs.

## 5. Contracts to settle before building features

### Data vocabulary

| Concept | Meaning and invariant |
| --- | --- |
| Capture | Original input plus processing state; acceptance by the server is distinct from successful extraction |
| Item | A useful structured record; one capture may produce multiple items |
| Reminder | A delivery intention with schedule, channel, lifecycle, and relationship to an item |
| Entity | A person, vehicle, home, subscription, or other supported organizing object |
| Relation | An explicit link between records with its own review/lifecycle semantics |
| Family share | An access grant for a particular item; family membership alone must not expose all personal data |
| Local draft | Unsubmitted work owned by one account/session; it is not a server-saved record |
| Cached record | A local representation of server data with freshness information |
| Pending mutation | Introduced only with a defined retry, conflict, and idempotency contract |

### Lifecycle decisions

Document every transition, who may perform it, and its side effects before implementing its UI.

| Lifecycle | Required states or decisions |
| --- | --- |
| Capture | Local draft; submitting; saved/pending; processing; completed; failed; fallback awaiting retry. Keep local upload states distinct from server processing states. |
| Item | Pending review, active, completed, snoozed, archived; unknown values remain readable. Confirm, reopen, reject, and delete need explicit meanings. |
| Reminder | Scheduled, sent, snoozed, dismissed, cancelled; distinguish provider acceptance from proven user delivery. |
| Session | Signed out, signing in, verification pending, authenticated, expired, suspended/revoked, deleting. |
| Screen | Loading, empty, content, stale cached content, saving, recoverable failure; later, pending synchronization and conflict. |

**Proposed first-release rule:** newly captured native text should require user review before its extracted dates trigger new automated behavior. This is a deliberate product recommendation, not current backend behavior: high-confidence extraction can currently activate items. Implement the agreed policy on the server and preserve existing records' state. A client-only review screen is insufficient.

Completion, deletion, and snoozing must have explicit reminder consequences. Reopening should present an intentional reminder choice or follow a documented shared rule; do not silently revive old alerts. Editing a due date must respect account preferences and preserve unrelated delivery settings.

### Date, money, and metadata semantics

1. Distinguish an instant, a local wall-clock time with time zone, and a date without a time. Do not convert every date-only value into UTC midnight.
2. Specify the time zone for “today,” overdue status, recurring reminders, and calendar export. Default to the user's chosen account zone; decide what happens during travel.
3. Agree on DST gaps/overlaps, month-end recurrence, leap days, missing dates, and explicit-time flags. Use a controllable clock in tests.
4. Preserve currency codes and decimal meaning. Do not default an unfamiliar or absent currency to INR or reinterpret monetary metadata silently.
5. Preserve unknown metadata on edits. The backend must define merge versus replacement behavior; the native client must not send a reduced replacement object that deletes recurrence, sharing, or source information.
6. Distinguish deleting an item from deleting its original capture. Confirm the actual cascades before writing the confirmation message.

### API agreement

Create a human-readable API contract and representative, redacted fixtures. An OpenAPI specification can follow when it improves validation or documentation; do not block the first vertical slice on tooling ceremony.

For each endpoint record method/path, authentication, ownership/capabilities, request fields, response fields, nullability, statuses, dates, errors, pagination, side effects, retries, and backward compatibility. The existing `/api/v1` prefix alone does not guarantee a stable contract.

Current routes to verify include account operations, item list/detail/create/edit/complete/delete, capture submit/list/retry/delete, reminders, events, relations, and families. Use real route behavior and controlled staging responses, not only API.md.

First-release reliability requires duplicate protection for capture submission and protection against stale overwrites. Those controls precede the later full offline queue. An `updatedAt` field without an enforced precondition is not a conflict protocol.

### Account and storage agreement

Keep existing account IDs and server data. Native Google login must reach the existing Google account; email/password login is not an equivalent substitute for a user without a password. Identity linking must require verified ownership and handle Apple's private relay identities deliberately. Do not automatically merge accounts merely because two providers return the same email address. Test linking, unlinking, recovery, and provider-token revocation as part of the account lifecycle.

Start by validating native cookie-based sessions with URLSession; a bearer-token rewrite is not inherently required. Define cookie/session persistence, secure credential storage, expiry, reauthentication, logout, account switching, and revocation. If testing identifies a reason for a dedicated mobile-token flow, record that decision and add it compatibly. Never embed database, AI, mail, or APNs provider secrets in the app.

The server remains authoritative. Initial offline behavior is cached reads and protected drafts. Mutations require a successful online acknowledgement. Show stale/offline state honestly; do not describe a cached screen as synchronized.

## 6. Release map

Versions below are planning labels. Each later subphase is a separate release if implemented. Features marked optional should be justified by feedback before work starts.

| Phase | Product increment | Distribution | Primary learning outcome |
| --- | --- | --- | --- |
| 0 | Verified scope, contracts, backend gates, native UX plan | Reviewed baseline | Turn source behavior into a maintainable specification |
| 1 | Adaptive shell and fixture-driven item flow | Internal TestFlight 0.1 | SwiftUI state, dependency boundaries, testing, CI |
| 2 | Existing accounts and connected organizer | Internal TestFlight 0.2 | Authentication, DTOs, concurrency, cache isolation |
| 3 | Text capture, processing, review, correction | **First public release 1.0** | Durable asynchronous workflow and AI consent |
| 4 | Native reminder delivery | Public 1.1 | APNs, lifecycle, schedule semantics |
| 5A | Waiting For and richer organization | Public 1.2 | Domain workflows and time-based behavior |
| 5B | User-confirmed calendar export | Public 1.3 | EventKitUI and platform boundaries |
| 6 | Reliable reconnect, pagination, optional offline writes | Public 1.4 | Reconciliation, idempotency, conflicts, migrations |
| 7A | Image capture and reviewed extraction | Next public increment | Native media pipeline and private storage |
| 7B / 7C | PDF extraction / audio capture | Optional separate increments | Format-specific processing and permissions |
| 8A / 8B | Entity relationships / Ask with citations | Separate gated increments | Cross-feature boundaries and AI evaluation |
| 9A / 9B | Family management/sharing / collaborative edits | Separate public increments | Authorization and shared-state behavior |
| 10 | Share extension, widgets, App Intents | Optional separate increments | Reusable modules and system integrations |

Phases 0–4 form the core path. From Phase 5 onward, reorder independent features based on feedback, recording dependencies first. Family collaboration requires conflict and authorization work; media requires private delivery; Ask requires retrieval evaluations. No later feature is necessary to declare the first release successful.

## 7. Phase-by-phase instructions

### Phase 0 — Establish the product and technical baseline

**Outcome:** A small first release whose behavior and prerequisites are understood.

**Study just in time:** API contract design, architectural decision records, current SwiftUI data flow, and Apple account/privacy requirements. Use the existing web application as a behavioral reference, not a screen specification.

**Steps**

1. Record the inspected commit and compare it with the currently deployed backend. Confirm staging and production API origins, ownership, account methods, and deployment process.
2. Walk the web core journey with test data. Record what happens for failed AI, unverified email, Google-only login, date edits, and completion. Re-run relevant backend tests in an isolated environment; do not use production data.
3. Create a compatibility dataset containing every existing item type/status, captures with several results, unsupported/future values, recurrence metadata, multiple currencies, existing shares, and media metadata.
4. Write the first-release promise: existing account access; text capture; review/edit; basic priority/timeline; item completion/reopen/delete; basic search; cached reads; safe drafts; iPhone/iPad support.
5. Mark exclusions: new media capture, advanced recurrence UI, Ask, entity management, family management, full offline writes, and extensions. Existing records still need readable fallback presentation.
6. Sketch the native navigation: compact Capture/Items/Settings destinations and a persistent add action; expanded sidebar/list/detail on iPad. Validate one-hand capture and keyboard-driven editing.
7. Approve the provisional deployment minimum against your actual devices. Record Xcode/Swift versions, bundle identifiers, environments, and signing setup. Confirm Apple Developer Program enrollment and App Store Connect access before planning TestFlight distribution.
8. Turn the backend findings into explicit prerequisites with acceptance criteria and an owner. For a solo project, you own both client and required backend work; estimate those separately.
9. Record architecture, session, data-source, date, notification-authority, and first-release scope decisions in the decision register.

**Exit gate:** You can explain the full core journey, identify the authority for each state, and list backend changes needed before each release. Staging exists or has a concrete setup task. No unknown public-release prerequisite is hidden inside a UI task.

**Rollout:** Review this baseline and freeze Phase 1 scope. There is no public binary yet.

### Phase 1 — Build the native foundation as a working vertical slice

**Outcome:** An installable iPhone/iPad app that demonstrates list → detail → edit using deterministic fixtures.

**Study:** Observation ownership, navigation state, MainActor, cancellation, dependency injection, Swift Testing, accessibility, and a simple CI pipeline. Skip introductory material you can already demonstrate.

**Steps**

1. Create the universal native app, test targets, and separate environment configurations. Set up source control and one CI service.
2. Create the logical boundaries in Section 4. Build the composition root and inject a small fixture repository.
3. Model only the fields needed for the slice, while allowing unknown item types/statuses and preserving metadata for later integration.
4. Build list/detail/edit and the loading/empty/error/saving states. Keep business decisions outside Views.
5. Implement compact navigation and expanded list/detail. Preserve selection and drafts during rotation and window resizing.
6. Define a small design system with native typography, semantic colors, Dynamic Type, light/dark appearance, and accessible control labels.
7. Add unit tests for real lifecycle/state behavior and one UI journey. Confirm the domain can be tested without a network or device permission.
8. Run on a physical iPhone and iPad when available. Use simulators for the broader size/OS matrix.
9. Produce an internal TestFlight build and a short walkthrough of the architecture.

**Exit gate:** CI passes; editing has a correct cancel/save flow; large text and VoiceOver remain usable; resizing does not lose work; another developer could trace an action through the boundaries.

**Rollout:** Internal 0.1. Fixtures are clearly test data. Do not collect durable personal data in this prototype. If persistence is used for an experiment, label the store as disposable and keep it separate from later account stores.

**Defer:** Login, production API calls, AI, push, and package proliferation.

### Phase 2 — Connect existing accounts and data

**Outcome:** Existing web users can sign in, see their records, and safely perform supported organizer actions.

**Study:** URLSession sessions, decoding/mapping, secure credential storage, structured concurrency, HTTP errors, partial updates, and account-scoped SwiftData storage.

**Backend prerequisites**

- Verify and fix ownership/authentication checks identified by source review: unverified-email changes, suspended accounts, user-triggered global reminder dispatch, and linked-item ownership when creating reminders. These are source-review concerns to reproduce in staging, not claims of verified production exploitation. Add regression cases for each relevant boundary.
- Provide password recovery, deletion, and the agreed revocation/session behavior. Account deletion must include existing captures, items, relations, shares, reminder records, and stored files according to a documented retention policy.
- Validate Google token audiences for native use. If Google sign-in is offered, plan an equivalent privacy-preserving login option, normally Sign in with Apple, and verify identity linking to existing accounts. Follow [Apple's login-services rules](https://developer.apple.com/app-store/review/guidelines/#login-services).
- Define narrow updates that preserve unrelated metadata, and stale-edit detection that prevents silent overwrites across web and native.
- Fix or explicitly specify due-date/reminder side effects before enabling date edits. Respect account settings across clients.

**Steps**

1. Implement sign-in, registration, verification, expiry/relogin, logout, and account settings against staging. Test existing Google-only and email accounts separately.
2. Establish safe credential persistence and clear all account-specific work on logout. Cancel requests and reject late responses belonging to the previous session.
3. Map actual API DTOs to domain values and cache records. Use fixtures from Phase 0 to validate nulls, dates, unknown values, and error bodies.
4. Add server-backed list/detail and supported create/edit/complete/reopen/delete actions. Indicate saving and failure accurately.
5. Preserve unsupported record types with readable generic details. Include a minimal read-only view of existing shared items for existing members, with server-verified access. Initially require an online authorization check for shared views and avoid persisting shared content for offline use. Clear it on logout or revoked access. Creation and management of families remain later work.
6. Show existing media metadata and related items. Use authenticated original-file access only when available; otherwise explain the native limitation and offer the web account page. Do not expose raw public upload URLs as a new native file feature.
7. Implement account-scoped cached reads and recoverable drafts. Label stale data. In this phase, writes require online acknowledgement and there is no general offline command queue.
8. Refresh on launch, foreground, pull-to-refresh, and successful mutation. Preserve draft input if the underlying record changes; fetch current state and offer an explicit conflict choice.
9. Implement recovery/deletion presentation and verify end-to-end deletion before external release. Apple's account-creation requirement includes an in-app way to initiate deletion: [account deletion guidance](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion).
10. Run the legacy-account walkthrough: find every category; edit one field without losing others; change the same record on web; resume native; sign out; sign into another account.

**Exit gate:** Existing IDs/data are retained; Google-only access works; no cross-account cache leakage; failed writes remain recoverable; stale writes do not silently win; no metadata loss; deletion/recovery work; backend regression tests pass.

**Rollout:** Internal TestFlight 0.2 with dedicated test accounts. This is the connected foundation for LifeLoop's core product release.

### Phase 3 — Ship text capture and review as version 1.0

**Outcome:** A useful native LifeLoop core, including the defining capture-to-action loop.

**Study:** Durable asynchronous operations, cancellation versus server processing, idempotency, state machines, AI uncertainty, and consent design.

**Backend prerequisites:** Repeated submission protection; recovery of stuck/interrupted processing; retry semantics that preserve user corrections; stable processing states; agreed review policy; bounded AI retries/cost. Existing fire-and-forget processing is not a complete durable-job guarantee.

**Steps**

1. Build a fast text composer with draft recovery and clear length validation. The inspected server limit is 10,000 characters; confirm it remains current and define Unicode counting consistently.
2. Before first AI submission, explain what content is sent, which external service processes it, and why; obtain the required explicit permission. Keep manual item entry available if AI is declined. See [Apple's data-sharing requirements](https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing).
3. Submit a capture using a stable client operation identifier. Preserve draft content until server acceptance is certain. On an ambiguous timeout, reconcile using that identifier before creating another capture.
4. Show “saved, processing” separately from “not saved” and “saved, AI unavailable.” Closing the screen cancels observation, not a durable server job.
5. Observe processing while the app is active with bounded polling initially. Refresh on foreground. Add SSE only when it improves this flow without becoming a dependency for correctness.
6. Build review with original text, extracted items, editable titles/types/dates, and explicit confirmation. Treat confidence as a system hint, not a truth guarantee.
7. Support retry, correction, and deletion with clear consequences. A retry must not duplicate confirmed items or overwrite a user's corrections.
8. Connect confirmed items to basic priority/timeline, scoped search, complete/reopen, and detail. Provide readable fallback states for every existing server item.
9. Profile a realistic account and long lists. Finish recovery, account deletion, privacy disclosures, accessible onboarding, support contact, and App Store metadata. Keep unimplemented destinations out of navigation; explain limitations when opening existing data that needs a later native capability.
10. Run the complete release checklist in Section 8, collect TestFlight feedback, fix blocking issues, then submit 1.0.

**Exit gate:** Capture survives interruptions; processing can recover after a server restart; duplicate taps/timeouts do not duplicate items; a user can correct an incorrect date; AI refusal/failure does not lose input; all earlier account/data guarantees still pass.

**Rollout:** Internal → external TestFlight → public 1.0. Observe completion/failure rates for capture and review, crash diagnostics, and data-integrity reports. Do not log raw personal captures to measure usage.

**Public promise:** Capture, organize, and act across the same account on web/iPhone/iPad. Native background reminder delivery is a later increment; existing server reminder settings remain intact and honestly described.

### Phase 4 — Deliver native reminders

**Outcome:** Reminders created or updated across clients can reach the correct signed-in devices.

**Study:** APNs registration/transport, UserNotifications, permissions, recurrence/date semantics, deep links, and the limits of iOS background execution.

**Default decision:** The server owns schedules for shared web/native data and sends remote notifications through APNs. Do not also schedule local alerts for the same reminder occurrence. A small local-notification learning experiment is useful, but is not the production delivery design for synchronized reminders.

**Steps**

1. Specify exact-time and date-relative behavior, timezone policy, quiet hours, recurrence, snooze, completion, reopening, and deletion effects. Separate per-account preferences from per-device permission state.
2. Replace the placeholder iOS provider with real APNs transport. Add authenticated per-device registration, token updates, environment handling, token invalidation, and logout/account-switch cleanup.
3. Define a stable reminder-occurrence identifier, retries, and duplicate suppression. Store provider acceptance separately from any claim of delivery; APNs acceptance is not proof the person saw it.
4. Request permission in context when enabling reminders. If denied, retain the in-app due list and explain how to change permission later.
5. Start with one-time reminders, then add recurrence only after month-end/DST cases pass. Each is independently releasable if the larger phase becomes too broad.
6. Route notification taps to the correct item after authentication. If the record was deleted or sharing revoked, show a safe unavailable state.
7. Use restrained notification content by default. Let users choose whether personal titles appear on the lock screen.
8. Test on physical devices: locked, backgrounded, app not running, offline/reconnected, permission revoked, token changed, and multiple signed-in devices. Test web edits before delivery.

**Exit gate:** Real APNs acceptance is observed; stale/duplicate occurrences are handled according to the contract; account changes detach delivery correctly; no provider mock is counted as successful production delivery; overdue information remains available in-app.

**Rollout:** TestFlight delivery cohort → public 1.1. Monitor dispatch delay, APNs rejection, invalid tokens, duplicate complaints, and scheduler health.

Neither remote nor local notifications guarantee delivery. Silent pushes may be delayed, throttled, or dropped; reconcile on foreground and do not use continuous polling as a background design. See [User Notifications](https://developer.apple.com/documentation/usernotifications), [background-push constraints](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app), and [permission requests](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications).

### Phase 5A — Expand daily organization and Waiting For

**Outcome:** Users can manage a larger set of responsibilities without losing the simple capture loop.

**Study:** Derived state, deterministic time rules, feature decomposition, scoped search, and workflow design.

**Steps**

1. Expand timeline into today/tomorrow/week/upcoming/history, with explicit attention and review indicators.
2. Define whether an item appears in more than one view and how counts avoid misleading duplicates. Separate urgency from “needs review.”
3. Add Waiting For entry/edit, received, snooze, and follow-up. Keep the person and expected date as supported domain concepts.
4. Make follow-up a user-controlled compose/share action. The web implementation opens a draft; do not imply mail was sent or correspondence is tracked.
5. Expand search/filter behavior with a visible scope. Integrate server search when pagination is introduced so results do not silently cover only loaded pages.
6. Recompute date-derived state at relevant lifecycle/time changes. Inject the clock for midnight, travel, and DST tests.

**Exit gate:** Review/overdue meanings are consistent; midnight changes do not require restarting; received/completed items move correctly; filters do not hide unknown records; snooze and reminder behavior agree.

**Rollout:** Public 1.2 after the standard beta loop. Measure whether users can find pending work and complete it without extra navigation.

### Phase 5B — Add calendar export

**Outcome:** A user can deliberately add a dated item to their calendar.

**Study:** EventKitUI, presentation bridging, date-only/all-day semantics, and permission minimization.

**Steps**

1. Start with the system event editor, prefilled from the item and presented for confirmation.
2. Define timed versus all-day events, duration defaults, timezone, title, and optional notes. Avoid inserting unnecessary sensitive content.
3. Record a successful editor save separately from cancel/failure. Handle repeated export and changed due dates without claiming an existing calendar event was updated.
4. Treat any calendar-added marker as historical app state, not proof that an event still exists.
5. If later offering managed updates, first add the necessary permission, identifier, and external-edit conflict design as a new increment.

**Exit gate:** Save/cancel behaves correctly; dates match the item; repeated exports are understandable; the UI promises one-way export.

**Rollout:** Public 1.3. On iOS 17+, EventKitUI can offer user-controlled event creation without broad calendar access; choose the appropriate access mode using [Apple's EventKit guidance](https://developer.apple.com/documentation/eventkit/accessing-calendar-using-eventkit-and-eventkitui).

### Phase 6 — Strengthen synchronization and introduce offline writes only if needed

**Outcome:** Reconnects, large accounts, and concurrent devices behave predictably. Offline mutations become an explicit optional capability.

**Study:** Cache invalidation, cursor pagination, transactional outboxes, idempotency, revisions, conflicts, actor isolation, and schema migrations.

**Steps**

1. Measure current list size, refresh latency, memory, and API load. Add server pagination and compatible search; retain support for older released clients.
2. Make cache reconciliation handle edits, deletions, and permission changes. Use full refresh for modest datasets; adopt delta cursors and tombstones when needed.
3. Treat SSE as an active-session optimization. Refetch after reconnect because the existing event stream has no replay history. Add shared event distribution before scaling to multiple processes if live consistency requires it.
4. Verify existing idempotency and revision preconditions across every operation you intend to queue, not just captures.
5. If offline edits are justified, begin with one operation such as text capture. Persist a durable outbox with operation ID, account, payload, base revision, attempt state, and ordering dependencies.
6. Define retry/backoff, authentication expiry, invalid payloads, deleted records, conflicts, and cancellation. Surface “pending,” “failed,” and “conflict” states distinctly.
7. Prefer an explicit conflict resolution screen to silently discarding edits. Apply simple field merges only when the semantics are demonstrably safe.
8. Test app termination at each handoff: before queue save, after request send, after server commit, and before local acknowledgement. Test migrations from the last public cache schema.
9. Keep shared-data offline access restrictive. Revocation cannot erase a disconnected device immediately; define cache expiration and purge on reconnect/logout, and explain that limit honestly.

**Exit gate:** Replaying an operation does not duplicate results; stale writes cannot overwrite newer data silently; account switches cannot replay another user's queue; deletes do not resurrect; a cache migration preserves drafts/outbox entries; permission changes remove access after reconciliation.

**Rollout:** Reliability improvements first, then one queued operation to a beta cohort. Public 1.4 may ship without general offline editing if demand does not justify the complexity.

### Phase 7 — Add media in separate releases

**Shared prerequisites:** Private durable object storage; authenticated or short-lived authorized downloads; ownership checks; file deletion/retention; actual format-specific extraction; upload size/MIME validation; progress/cancel/retry; no secrets in the client. These are backend and client tasks.

**Study:** Photos/Files pickers, file lifecycle, memory usage, background transfer where warranted, and asynchronous extraction. Prefer system pickers and request only permissions required by the chosen flow.

#### Phase 7A: Images

1. Start with image selection through a system picker; add direct camera capture only when needed.
2. Validate supported formats and dimensions, account for orientation, bound memory use, and disclose any resizing/compression.
3. Prove the backend receives image data and extracts useful fields; a URL placed in a text prompt is not proof.
4. Show upload state separately from extraction state, retain the original, and route results through existing review.
5. Test interrupted transfer, oversized files, unsupported formats, poor-quality images, duplicate submission, and deletion of source plus derivatives.

**Exit/rollout:** A user can select a receipt or notice, correct extracted fields, and recover from failure. Release images alone after beta validation.

#### Phase 7B: PDFs and documents — optional

1. Add document import with security-scoped access as appropriate.
2. Specify supported formats/pages/size and password-protected-file behavior.
3. Distinguish text PDFs from scanned PDFs; add OCR only when the extraction path supports it.
4. Preserve page/source references for extracted claims and test large or malformed documents.

**Exit/rollout:** Supported documents extract predictably with honest limitations; unsupported files fail recoverably. Ship separately from image capture.

#### Phase 7C: Audio — optional

1. Define recording versus audio-file import, supported duration/size/languages, and storage policy.
2. Choose transcription location/provider deliberately and disclose content transfer.
3. Handle microphone permission, interruption, cancellation, and transcript review before item extraction.
4. Test inaccurate transcription, silence, long recordings, and interruption during saving/upload.

**Exit/rollout:** Audio and transcript survive recoverable failures; users can correct text before accepting extracted items. Ship separately from PDFs.

### Phase 8 — Add knowledge features only after the core is trusted

#### Phase 8A: Entities and relationships

**Study:** Relationship modeling, cross-feature navigation, ownership boundaries, and deletion cascades.

1. Define supported entity types and the current admin/product-access policy.
2. Build a searchable entity directory and related-item detail using existing records. Start with lists; an interactive graph is optional new scope.
3. Add explicit connect/disconnect and relation-review actions with authorization and duplicate prevention.
4. Test missing/deleted targets, unknown types, and relationships involving shared records.

**Exit/rollout:** Links remain navigable and authorized; deletion has defined consequences. Release entity management independently of Ask.

#### Phase 8B: Ask My Life

**Study:** Retrieval scope, grounded generation, structured output validation, uncertainty, and evaluation datasets.

1. Decide whether Ask remains admin-only, enters a controlled beta, or becomes a general capability. Enforce the decision server-side.
2. Remove invented fallback values. Missing data must produce an honest lack-of-information response.
3. Define retrieval scope and freshness. The current latest-100-owned-items implementation must not be marketed as complete search of all personal/family history.
4. Build a redacted evaluation set: answerable, unanswerable, contradictory, old, recently changed/deleted, malicious stored instructions, and other-user records.
5. Present an answer with navigable supporting items and a clear unavailable state when a citation is no longer accessible.
6. Reuse AI consent controls. Define cancellation, limits, cost monitoring, and whether history is stored; the web component's transient chat is not a durable history contract.

**Exit/rollout:** Every asserted fact has valid support or appropriate uncertainty; no cross-user evidence appears; missing values are never invented. Run a controlled beta before public availability. Ask does not autonomously mutate items in this phase.

### Phase 9 — Build family collaboration in two increments

**Entry requirement:** Existing shared-data read compatibility from Phase 2, reliable account identity, and the conflict/permission foundations needed by the chosen scope. Keep Family separate from Apple's purchase-sharing terminology.

**Study:** Capability-based authorization, invitation links, role matrices, revocation, and concurrent editing.

#### Phase 9A: Management and explicit sharing

1. Write a role/action matrix covering create, invite, accept, view, share, unshare, remove, leave, and delete-family operations.
2. Build creation, invitation, accept/reject, and member management. Invitation links must survive installation/sign-in and still validate the intended identity server-side.
3. Add explicit item sharing with a clear scope. Personal items stay private unless shared.
4. Support read-only shared items, in-app activity, and refresh after membership/share changes.
5. Test revoked invites, expired links, removed members, unsharing, owner account deletion, cached data, and pending operations.
6. Decide basic abuse-handling and support behavior appropriate to private invitations before opening broader sharing.

**Exit/rollout:** Every role/action is checked on the server; revoked access is rejected and purged on reconciliation; unrelated family/private data never appears. Release management/read sharing first.

#### Phase 9B: Collaborative editing — optional until requested

1. Add actual shared mutation authorization; do not rely on the existing `canEdit` response flag alone.
2. Define who can complete, delete, change due dates, and change reminder ownership. Editing a shared item does not automatically grant control over another person's notification preferences.
3. Apply version checks/conflict handling, and deliver invalidation to affected authorized users.
4. Test two members editing simultaneously, access revoked during edit, account deletion, and an offline mutation after revocation.

**Exit/rollout:** Shared edits are authorized and conflict-safe; removed members cannot replay pending changes. Release this independently from family management.

### Phase 10 — Add native conveniences one at a time

**Outcome:** Faster entry and retrieval using stable capabilities already shipped in the app.

**Study:** App extensions, App Groups where needed, WidgetKit, App Intents, and extension resource constraints.

1. Choose the next integration from observed friction. A share extension for text/URLs is a sensible first candidate.
2. Define its authentication, draft handoff, data minimization, and failure behavior. Share code through narrow reusable modules.
3. Add a widget only with clear stale-data and privacy behavior. A widget is not a real-time always-running view.
4. Add App Intents/Shortcuts for a small supported action, respecting account state and consent.
5. Improve iPad keyboard shortcuts, drag/drop, and multiwindow only when they solve a real workflow. Shared mutable persistence must remain safe across scenes/extensions.

**Exit/rollout:** Each integration works when the main app is closed, signed out, or offline according to its documented contract. Release one integration at a time and retain the standard regression suite.

## 8. Quality and rollout gates

### Definition of done for every feature

- [ ] The user outcome and exclusions are documented.
- [ ] Business behavior lives in the appropriate boundary; no new dependency cycle is introduced.
- [ ] Loading, empty, error, cancellation, and permission-denied states are usable where relevant.
- [ ] Existing account/data compatibility is preserved, including unknown metadata.
- [ ] iPhone and iPad layouts work at compact and expanded widths.
- [ ] Relevant tests prove meaningful rules, side effects, or failure recovery.
- [ ] Privacy disclosures, purpose strings, and permissions match the actual feature.
- [ ] Logs and diagnostics exclude credentials and raw personal content.
- [ ] Upgrade/migration and previous-client compatibility are checked when data/contracts change.
- [ ] The phase's TestFlight feedback has been addressed and the release log updated.
- [ ] You can explain the design and failure path without relying on generated explanations.

### Test strategy

| Layer | What to prove | When |
| --- | --- | --- |
| Domain | Lifecycle transitions, dates, timezones, metadata preservation, conflict rules | As each rule is introduced |
| ViewModel | Loading/saving/error state, cancellation, session changes, retry behavior | For stateful feature logic |
| API contract | Actual request/response fixtures, unknown/null fields, errors, auth, revisions | Before integrating a route; on backend changes |
| Repository/persistence | Account partitioning, migration, cache reconciliation, outbox recovery | When those capabilities change |
| Backend integration | Authorization, deletion cascades, idempotency, side effects | Before exposing corresponding native behavior |
| UI | Sign-in → capture → review → complete; draft recovery; key iPad navigation | Small stable set on CI and release candidates |
| Physical device | Notifications, pickers, background/foreground, permissions, keyboard | Before the related feature release |
| Performance | Realistic/larger account list, launch, scroll, memory, processing workload | Establish baseline at 1.0; remeasure affected flows |

Avoid tests that merely repeat trivial view structure or implementation details. Prefer behavioral assertions and deterministic clocks/data. Keep backend tests isolated from production. Apple documents the available test tooling in [Testing in Xcode](https://developer.apple.com/documentation/xcode/testing).

### Device and failure matrix

Test a small supported iPhone, a larger iPhone, and an iPad in full and narrow windows; the oldest supported OS and the current release; light/dark, large Dynamic Type, VoiceOver, keyboard, and orientation changes. For each data feature cover offline start, network loss, timeout after commit, server error, authentication expiry, app termination, web changes, and account switching. Add platform permissions only when the feature uses them.

Set numeric performance targets after measuring the Phase 2 baseline on named devices and datasets. Record them before 1.0. Do not choose arbitrary “scale” targets without a known workload.

### Release procedure

1. Freeze the increment's scope and resolve all blocking data-loss, authorization, core-flow, and migration issues.
2. Run CI plus targeted backend/contract checks. Exercise the legacy-account walkthrough and the relevant physical-device cases.
3. Validate against staging, then verify production configuration without using production for destructive tests.
4. Prepare the version/build, release notes, privacy answers, SDK/privacy-manifest review, screenshots, support/privacy URLs, and a review account or approved demo arrangement.
5. Distribute internally, then externally when appropriate. Define the journeys testers should attempt and collect actionable reports. Reserve a stabilization interval for those results; do not begin the next feature solely because a build uploaded successfully.
6. Submit a useful, complete build with the backend available. Apple reviews the first external TestFlight build; plan that lead time. See [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).
7. For eligible updates, consider Apple's phased rollout. It distributes automatic updates over seven days, while manual downloads remain possible; it is not a feature-access control. See [phased releases](https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases).
8. Monitor meaningful outcomes: core journey failures, crashes, rejected saves, processing delays, notification-provider failures, and integrity reports. Capture content is not an analytics payload.
9. Pause an update rollout or disable the affected server capability if serious issues emerge. Ship a corrective version; do not assume you can remotely downgrade installed apps.
10. Preserve compatibility during rollback. Database rollback must not destroy data written by a newer client. Keep backups and prove restore procedures in staging before risky migrations.

Check [App privacy details](https://developer.apple.com/app-store/app-privacy-details/), [privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files), and [submission requirements](https://developer.apple.com/news/upcoming-requirements/) at release time. Requirements can change over this project's lifetime.

## 9. Working and learning process

### One development slice

Use this sequence for each small piece of work:

1. State the user-visible behavior and a failure case in plain language.
2. Identify the unfamiliar concept and read the relevant primary documentation.
3. Trace the proposed action through the architecture; name the state owner and side effects.
4. Implement the smallest end-to-end slice during development.
5. Prove the important behavior with a focused test or deliberate device check.
6. Explain why the design works, what can fail, and why an alternative was deferred.
7. Update the guide/decision record and demonstrate the result before adding scope.

Do not front-load a complete course in Swift, databases, AI, and distributed systems. Learn each concept when the current slice needs it. If using AI assistance during implementation, ask for reasoning, tradeoffs, and review; retain ownership of every behavior you ship.

### Task template

For each development task, record: phase; user outcome; current behavior; desired behavior; included/excluded scope; module owner; backend dependency; data/permission implications; acceptance scenarios; validation evidence; learning objective; release target.

Examples of appropriately small tasks: “restore a text draft after termination,” “show an unknown item type safely,” “reject a stale title edit,” and “open a reminder's item after sign-in.” “Build sync” is too broad until decomposed into such behaviors.

### Decision record template

Record: decision ID/date; problem; chosen approach; alternatives considered; reason; consequences; evidence; what would cause reconsideration. Keep decisions short enough to revisit. Update this guide when a decision changes a phase or contract.

### Release record template

Record: version/build; client/backend revisions; shipped scope; migrations; test evidence; known limitations; feedback; incidents; observed metrics; follow-up tasks; decision to proceed or stabilize.

### Phase status tracker

| Phase | Status | Build/release evidence | Learning demonstrated | Next action |
| --- | --- | --- | --- | --- |
| 0 | Planning baseline drafted | This guide | Pending your walkthrough | Validate deployed/staging contracts |
| 1 | Not started | — | — | After Phase 0 exit gate |
| 2 | Not started | — | — | After foundation and account prerequisites |
| 3 | Not started | — | — | First-public-release core loop |
| 4 | Not started | — | — | Real APNs and reminder contract |
| 5A / 5B | Not started | — | — | Reassess after core feedback |
| 6 | Not started | — | — | Measure and prioritize reliability |
| 7A / 7B / 7C | Not started | — | — | Private storage and extraction proof |
| 8A / 8B | Not started | — | — | Product access and evaluation gates |
| 9A / 9B | Not started | — | — | Sharing and conflict gates |
| 10 | Not started | — | — | Choose a demonstrated convenience need |

### Learning references by need

| Need | Primary reference | Use it for |
| --- | --- | --- |
| Refresh Swift only where needed | [The Swift Programming Language](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/) | Values, protocols, errors, generics |
| Concurrency | [Swift concurrency guide](https://docs.swift.org/latest/documentation/the-swift-programming-language/concurrency/) | Tasks, cancellation, actor isolation |
| Modern native development | [Develop in Swift](https://developer.apple.com/tutorials/develop-in-swift) | Targeted practical refreshers |
| SwiftUI state ownership | [Managing model data](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app) | Observation and UI dependencies |
| Adaptive navigation | [NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview), [split-view design](https://developer.apple.com/design/human-interface-guidelines/split-views) | iPad resizing, compact/expanded navigation |
| Persistence | [SwiftData](https://developer.apple.com/documentation/swiftdata) | Local records, context ownership, migrations |
| Networking | [URLSession](https://developer.apple.com/documentation/foundation/urlsession) | Requests, sessions, cancellation |
| Credential storage | [Keychain Services](https://developer.apple.com/documentation/security/keychain-services) | Session-secret storage and access policy |
| Notification delivery | [UserNotifications](https://developer.apple.com/documentation/usernotifications) | Permission, scheduling, remote notification handling |
| Calendar export | [EventKit and EventKitUI access](https://developer.apple.com/documentation/eventkit/accessing-calendar-using-eventkit-and-eventkitui) | User-confirmed calendar operations |
| Native quality | [Accessibility](https://developer.apple.com/accessibility/), [testing](https://developer.apple.com/documentation/xcode/testing) | Usability and behavioral verification |

## 10. Decision and risk register

### Decisions established by this plan

| ID | Decision | Status |
| --- | --- | --- |
| D01 | Same existing backend/account/data from first public release | User requirement |
| D02 | Learning assumes prior iOS app-building experience | User preference |
| D03 | Native SwiftUI with MVVM and focused Clean boundaries | Recommended baseline |
| D04 | Express/PostgreSQL remains authoritative; no parallel CloudKit system | Recommended baseline |
| D05 | First public release includes text capture and review | Recommended product scope |
| D06 | iOS/iPadOS 17 provisional minimum; current stable submission toolchain | Validate device audience in Phase 0 |
| D07 | Cached reads/drafts first; full offline mutation queue later | Recommended scope control |
| D08 | Server/APNs owns synchronized reminders | Recommended notification design |
| D09 | New native AI captures require review before automated effects | Requires compatible backend agreement |
| D10 | Existing shared items get read compatibility; family management later | Recommended compatibility scope |
| D11 | Media, entities, Ask access policies remain enforced until deliberately changed | Confirm product policy before those phases |

### Risks with concrete gates

| Risk | Consequence | Required response |
| --- | --- | --- |
| Stale docs/types | Incorrect decoding or silent data loss | Current fixtures and contract tests before Phase 2 |
| Missing account lifecycle / authorization gaps | Users locked out or incorrect access | Staging reproduction, backend fixes, account tests before public release |
| Hidden reminder side effects | Surprise alerts or cancelled schedules | Shared mutation/lifecycle contract before editing ships |
| In-process capture work | Stuck processing after restart | Durable recovery and duplicate protection before 1.0 |
| APNs placeholder | UI reports delivery that never happened | Real transport and device evidence before Phase 4 |
| Public/ephemeral file storage | Private-document exposure or loss | Private durable storage before native file delivery/upload |
| Unproven extraction | Imported media produces incorrect claims | Format-specific evaluation and review before each Phase 7 release |
| Lost updates and duplicate retries | User data corruption | Precondition/idempotency rules early; outbox only after full contract |
| Fabricated Ask fallback | Unsupported factual answers | Remove defaults, evaluate citations/unanswerable cases before Ask |
| Shared-permission mismatch | Unauthorized or falsely advertised editing | Server role/action matrix and integration tests before collaboration |
| Excessive scope | Long delay without a usable app | Finish one slice, ship, review feedback, then reprioritize |

Questions to resolve during Phase 0 are deployment/staging access, intended device audience, target languages/regions, provider/account configuration, who will test releases, and which advanced features should remain restricted. They do not prevent beginning the specification and fixture work.

## 11. Your first working session

1. Read Sections 2–5 and annotate any product behavior you want to change.
2. Record the current deployed backend revision and staging API origin; keep them separate from production.
3. Perform one existing-account walkthrough using email login and one using Google login.
4. Capture redacted response fixtures and create the compatibility dataset.
5. Write the first four decision records: architecture, account/session handling, authoritative storage, and date/reminder behavior.
6. Sketch the compact and expanded capture → review → item-detail flow.
7. Convert Phase 1 into small tasks using the template in Section 9.
8. Begin implementation only after Phase 0's exit gate is met. Update this document as decisions become verified facts.

**Development principle:** Each release should make LifeLoop more useful, preserve trust in existing data, and leave you able to explain the engineering decisions behind it.
