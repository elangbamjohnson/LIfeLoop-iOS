# LifeLoop iOS — feature-first execution roadmap

**Prepared: 18 November 2026. Audience: Johnson, the implementation agent, and the reviewing ChatGPT web conversation.**

## 1. Decision and working agreement

Build the user-facing capabilities of the existing LifeLoop web app in small, complete native feature PRs. After the feature pass, run a separate improvement and release-readiness pass.

The two goals remain learning the implementation and producing a production-ready iPhone/iPad app. Feature-first changes the order of work; it does not mean that partially working screens are complete or that private-data boundaries can wait.

This roadmap **supersedes the sequencing and early public-release cadence** of `LifeLoop_iOS_Final_Master_Guide_v2.0.md`. Keep that guide for product context, data compatibility, architecture, and eventual release requirements. Do not restart its earlier phases or require every original hardening gate before moving to the next development feature.

Use `F` identifiers below to avoid confusing the new milestones with the old guide's phase numbers. A milestone can contain several PRs. Each PR delivers a coherent user action or closely related workflow end to end: UI, state, real API adapter, and focused validation. Avoid spending separate PRs on every class or layer.

Development rollout means integration into the development main branch and simulator/manual verification. Public release is a separate decision. Apple Developer signing remains on hold, so TestFlight/APNs-dependent results must be marked pending rather than claimed complete.

### What we keep in every feature

- A usable normal path on iPhone and iPad, with loading and a readable failure state.
- Authenticated access to the correct account; no cross-account cache/token leakage.
- Preserve unrelated item fields. Keep existing revision protection for edits.
- Show success only after the server acknowledges the operation. Disable duplicate taps while submitting.
- Keep entered text on ordinary request failure. Do not blindly retry a write after an uncertain network response.
- Confirm destructive user actions and respect existing role restrictions.
- Add focused tests for the feature's actual contract/rules; retain existing regression tests.

These are baseline behavior, not an invitation to build a general synchronization engine.

### What normally waits for the improvement pass

Exhaustive race/failure combinations, full offline mutation queues, sophisticated conflict merging, pagination before it is needed, advanced retry infrastructure, performance tuning without measurements, broad architecture rewrites, full design polish, elaborate animations, and exhaustive accessibility audits.

Basic readable layouts, accessible control labels, and permission-denied handling remain part of a usable feature. Concrete data-loss or authorization defects found during implementation still need a bounded fix.

## 2. Evidence and current status

Web reference: [LifeLoop](https://github.com/elangbamjohnson/LifeLoop). Verified remote main at inspection: `8c55c5d586e4fb12c539c0649e6b2b3d7cb30bc9`, merging PR #27. The local backend branch's tree matches that main commit's tree; its feature files were used for this inventory. Recheck contracts when implementation starts, since main can change.

iOS reference: [LIfeLoop-iOS](https://github.com/elangbamjohnson/LIfeLoop-iOS). Current branch: `feat/ios-revision-aware-title-editing`. The learning-guide commit `adf21e6` was pushed, but the inspected title-editing implementation is still **uncommitted local work** across 19 source/test/configuration files. Do not assume GitHub or a new web chat contains those changes.

Current iOS source contains:

- Google sign-in, LifeLoop session exchange, Keychain storage, session restoration, and explicit sign-out.
- Account-scoped item cache and drafts; list/detail UI with adaptive navigation.
- Revision-aware title PATCH, canonical response mapping, cache-update attempt, and title-editing controls enabled through `.titleOnly`.
- Swift Testing tests, demo UI tests, and iPhone/iPad CI configuration.

Connected create/complete/reopen/delete are still unavailable. Capture, native reminder delivery, calendar export, family UI, Ask, and Graph are not implemented in the native app.

The user reported backend deployment and migration completion. An earlier browser screenshot showed `revision: 5` in a live items response. Live successful title PATCH and stale-edit 409 results were not supplied in this conversation. This review inspected source and diffs; it did **not** run the iOS test suite or independently exercise the live app.

## 3. Bounded review of the current title-editing work

Keep the implemented repository, DTO, capability, and cache structure. No rewrite is needed. Positive changes include a narrow `{title, expectedRevision}` request, response identity/revision validation, separate title permissions, and tests for rejected/unsupported mutations.

Before calling this feature complete, address these concrete behaviors in **one closeout increment**, not a series of architectural projects:

| Finding | Current source behavior | Smallest acceptable closeout |
|---|---|---|
| Legacy draft can adopt a newer revision | `ItemEditView.init` starts with `item.revision`; a legacy timestamp mismatch only sets a warning. `save()` does not block based on that warning. An old draft can therefore submit against the latest revision without explicit reconciliation. | Keep the old text, but treat its base as unverified. Require an explicit review/reload choice before enabling Save; never invent a revision or discard the text. |
| “Reload latest” can report success without a fresh result | `RootView` calls `forceLoad()`, which can fall back to cached data; if no item is found it returns the old item. The editor then clears its conflict state. | Use a small explicit online fetch for conflict reload; propagate failure/missing item. Display the latest title alongside the retained draft before the user chooses to apply their draft. No general merge engine. |

Both are about the feature's promise to avoid unnoticed lost edits. They are not demands for exhaustive corner-case handling.

As part of that same small editor touch, reset `isReloading` with `defer` so cancellation cannot leave the editor disabled. Route save-time 401 through the existing sign-in recovery rather than building a new auth subsystem. Persist a newly accepted draft base when it changes.

Record, but do not block unrelated features on: silent cache-persistence failures after server success, snapshot timestamp accuracy, compatibility helper cleanup, exhaustive cancellation tests, and broader layer isolation. No new fix should be labeled blocking without a concrete trigger and user impact.

F0 validation should cover a successful canonical save, retained draft on failure, a stale/legacy draft decision, and a failed reload that stays failed. Use mocks for deterministic cases, plus one dedicated-account manual save/conflict walkthrough on the deployed service. Existing CI must pass before merge. If live verification is unavailable, mark it pending; other feature coding may continue without claiming F0 is verified.

## 4. Web feature inventory and native equivalents

| Actual web capability / source | Native destination | Important scope distinction |
|---|---|---|
| Google auth, email login/registration, verification, change-email (`features/auth`, `api/v1/auth.ts`) | Account | Google is already implemented; email flows come late in this pass. Password recovery/account deletion need contract work, not imaginary existing endpoints. |
| Priority, timeline, search, review, history (`Dashboard.tsx`, `shared/utils/timeline.ts`) | Organizer | Match grouping and search meaning; native layout need not copy HTML. |
| Edit title/type/date, amount/currency, Waiting For (`ItemEditModal.tsx`) | Organizer editor | Preserve unknown metadata and unchanged dates. |
| Complete/reopen, snooze, delete, confirm AI (`Dashboard.tsx`, `items.ts`) | Organizer actions | Use actual endpoint semantics; complete/reopen share one endpoint. |
| Text capture, processing/history, retry/delete (`CaptureDialog.tsx`, `captures.ts`) | Capture | Saved capture and AI-processed result are separate states. |
| Reminder options and preferences (`PreferencesModal.tsx`, `reminders.ts`) | Reminders / Settings | Browser notification permission is not iOS permission. |
| Calendar export and added marker (`AddToCalendarButton.tsx`) | Calendar export | One-way user-confirmed export, not two-way calendar sync. |
| Image, audio, document upload (`CaptureDialog.tsx`) | Media capture | Web UI is admin-gated. Camera/microphone icons do not prove live recording is implemented. |
| Ask My Life (`AskView.tsx`, `ask.ts`) | Ask | Admin-only API; answer plus source items. |
| Life Graph/entity connections (`LifeGraphView.tsx`, `EntityDetailView.tsx`) | Knowledge | Web presents entity cards and connections; no need for a custom physics graph. Graph tab is admin-gated. |
| Family list/create, members/invites, shared items, notifications (`features/family`, `families.ts`) | Family | Role-aware access; a `canEdit` field alone does not establish a working shared-write contract. |
| Theme, account menu, reminder settings | Settings | Native system/light/dark preference replaces web theme plumbing. |
| Foreground polling and SSE (`useDashboardPolling.ts`, `useLiveSync.ts`) | Refresh / later live updates | Foreground freshness first; SSE is an optimization, not offline/background delivery. |
| Install/PWA prompts | No native feature needed | App installation replaces “install website”; do not rebuild browser-only behavior. |

The web editor currently offers payment, renewal, subscription, appointment, warranty, waiting_for, task, deadline, purchase, document, and reminder. Unknown types should remain readable. Knowledge also surfaces person, vehicle, home, and subscription entities. Use actual API/route behavior over potentially stale shared type declarations.

Manual item creation is an existing backend capability and an original-guide goal, but a dedicated web creation form was not established by this review. Include a small native form as a deliberate product addition, not a claim of an observed web screen. Similarly, backend-only role editing or relation-edit routes do not automatically justify a native screen in this pass.

## 5. Execution sequence: one feature increment per PR

Statuses initially: **F0 in progress; all others planned.** PR labels below are planning IDs, not GitHub PR numbers. Split an increment only when it cannot remain understandable as a reviewable user workflow; do not split just to satisfy layers.

### F0 — Finish the connected title-editing slice

**PR F0.1:** Close the two concrete review issues above, verify, and explain the existing flow. Use the current branch; preserve unrelated changes. Outcome: a real-account title edit survives refresh and a conflict does not silently overwrite unseen changes.

**Learning:** optimistic concurrency, callbacks versus bindings, canonical server responses. **Stop:** once the bounded behavior and checks pass; move to F1. Commit/push/merge only when requested.

### F1 — Make existing items actionable

**PR F1.1 — Complete, reopen, snooze, delete.** Connect existing controls to real endpoints. Completion/reopening uses `POST /items/:id/complete` with `completed`; snooze uses `POST /items/:id/snooze`; delete uses `DELETE /items/:id`. Refresh/reconcile after acknowledgement. Confirm deletion and keep failed actions visible.

**PR F1.2 — Basic manual item creation.** A small title/type form using `POST /items`. Show the returned item immediately and after reload. No advanced form builder or attachments here.

**Done:** a user can create a test item, complete/reopen it, snooze it, and delete it, with matching web state. **Learning:** mutation contracts and reusable action state.

**Contract caution:** current complete/snooze/delete routes do not enforce `expectedRevision` like PATCH. Do not pretend an ignored request field adds protection. Use their narrow explicit action semantics and acknowledge concurrency limits. If a necessary overwrite-prone edit requires a backend addition, make the smallest paired backend change; do not redesign every mutation route first.

### F2 — Deliver the defining capture-to-review loop

**PR F2.1 — Text capture and capture history.** Add `Features/Capture`, a text composer, POST submission, capture history, actual processing statuses, and bounded foreground refresh while work is pending. Preserve text until acknowledgement. Validate against the real 10,000-character contract, considering server/client string-count differences. Explain AI processing before first submission; use the existing server AI, not an iOS AI SDK.

**PR F2.2 — Capture result review, retry, delete.** Associate resulting items with the capture, show pending-review items, confirm them with the existing PATCH contract, allow title correction through the shared editor, and retry/delete captures using server endpoints. Explain deletion consequences from the actual handler.

**Done:** capture text → see pending/processing → see resulting items → review/confirm → reopen history; failures retain a usable recovery action. **Learning:** asynchronous server workflows, polling, state machines, reuse across features.

**Defer:** a durable general job queue and automatic resubmission. Current server work is partly fire-and-forget and POST lacks established idempotency. On an ambiguous timeout, refresh history and let the user reconcile before resubmitting; do not automatically create a duplicate. Store recovered server IDs when known. Add idempotency later, or as a narrowly scoped backend prerequisite if the chosen workflow genuinely requires automated retry.

### F3 — Match everyday organization

**PR F3.1 — Priority, timeline, search, and history.** Add native destinations and shared grouping logic for needs-attention/review, today, tomorrow, week, upcoming, undated, and completed/history as present in web. Search title/type and the metadata actually searched by web. Recalculate on foreground/date change. Test representative date boundaries; exhaustive timezone combinations wait.

**PR F3.2 — Richer item editing and Waiting For.** Extend the form to the supported web type/date and amount/currency/waiting-person fields. Reuse narrow revision-aware PATCH. Preserve existing time semantics when a date is untouched. Add Received and follow-up composition for Waiting For using the existing completion behavior; follow-up opens a user-controlled mail/share draft, not an automatic message.

**Done:** users can find and edit each supported item category, use Waiting For, and see consistent placement after refresh. **Learning:** derived state, date formatting, metadata, and form composition.

### F4 — Reminder management and preferences

**PR F4.1 — Reminder settings.** Read/save auto-reminder preferences, offsets, supported channels, timezone, email preference, and quiet hours through `/reminders/preferences`. Clearly distinguish account preferences from this device's notification permission. Do not advertise placeholder iOS delivery as working.

**PR F4.2 — Item reminder workflow.** Show relevant reminders; wire supported relative offsets, recurrence options, snooze/edit/delete behavior from the web editor/API. Ensure completion/deletion behavior is reflected after refresh. Start with simple UI and the actual supported server values rather than inventing recurrence rules.

**Done:** web and iOS read the same schedules/preferences; ordinary edit/snooze/complete behavior is verified. **Learning:** scheduled domain data, side effects, preferences, recurrence representation.

**Explicit gap:** real APNs delivery remains tracked separately in R1 while Apple setup is deferred. The inspected `IOSNotificationProvider.send` constructs a payload and returns a delivery-shaped result without contacting APNs. That is not working native delivery. Do not replace shared server schedules with duplicate local alerts to mark this feature complete.

### F5 — Calendar export

**PR F5.1 — User-confirmed native calendar export.** Use a system calendar editor (EventKitUI) or an appropriate authenticated export flow after checking current Apple APIs. Support date-only versus timed events, Save/Cancel, and the existing calendar-added marker/undo contract.

**Done:** a dated item can be exported deliberately; Cancel never records success; a marker reset does not claim it deleted an external calendar event. **Learning:** UIKit/SwiftUI bridging and OS permission boundaries. **Defer:** two-way sync, tracking arbitrary external calendar edits, and automatic event replacement.

### F6 — Media capture, in separate useful increments

**PR F6.1 — Select/upload images.** Use PhotosPicker, display selection, send multipart upload to `/captures`, and reuse history/status/result UI. Preserve admin gating from the web UI. Enforce server MIME/size requirements; the inspected upload limit is 10 MB.

**PR F6.2 — Import documents.** Add file import for supported PDF/document formats, names, upload progress/basic failure, and processed results. Confirm actual extraction support rather than trusting the browser accept list. Original-file viewing requires authorized retrieval; current public upload serving is not a private-file access design.

**PR F6.3 — Import audio.** Select an audio file and reuse processing/result flow. Verify supported formats. Live microphone recording is optional native enhancement, not required to match the observed web file picker.

**Done:** each supported format completes a real upload-to-result workflow for an authorized user. **Learning:** PhotosUI, file access, multipart encoding, transfer state. **Backend condition:** if private original access or role enforcement is needed, add the narrowly scoped route before exposing it. Keep metadata/results usable while originals are blocked. Do not call an upload-only stub complete media parity.

### F7 — Knowledge and Ask My Life

**PR F7.1 — Entity cards and related items.** Implement native entity list/detail and existing connect/disconnect workflow using `/items` and `/relations`. Reuse item details. Preserve the web Graph tab's admin visibility; every data operation still needs server authorization.

**PR F7.2 — Ask My Life.** Admin-gated question input, answer state, source citations, and navigation/actions on cited items using `POST /ask`. Show an honest empty/no-answer or unavailable state. Keep conversation ephemeral initially unless the backend supports persisted history.

**Done:** an authorized user can browse connections and ask a question, then open its real cited item. **Learning:** linked domain models, conversation state, citation-driven navigation. **Defer:** custom animated graph layouts, streaming, vector database changes, and new AI providers.

### F8 — Family collaboration

**PR F8.1 — Family browsing and shared reads.** List families, members/roles, shared categories/items, and family notifications; mark notifications read. Fetch shared content with current authorization and do not introduce offline shared-data persistence in this pass.

**PR F8.2 — Create family and invitation workflow.** Create a family, invite supported roles, accept/reject invitation tokens, and show membership updates. Native paste/open-invite handling can be the initial flow while associated-domain setup is unavailable; universal-link routing can follow in R1.

**PR F8.3 — Share/unshare and member removal.** Implement the web's sharing/category/visibility controls and permitted member removal. Respect server roles. Only add family rename/delete/role-change UI if it is an agreed existing user workflow; otherwise record those backend-only capabilities separately.

**Done:** two dedicated accounts can complete invite → join → share → view → unshare/remove, and removed access is rejected after refresh. **Learning:** role-based UI, multi-account testing, navigation from external input.

Shared writes are not assumed from a `canEdit` field. If the web truly supports an editable shared-item workflow, verify its actual authorized route and add a small F8.4. Otherwise read-only sharing matches the demonstrated feature and shared editing is an explicit future extension.

### F9 — Account and appearance parity

**PR F9.1 — Settings and appearance.** Account summary, sign-out/local cleanup, system/light/dark choice, and a home for existing reminder preferences. Basic native settings only.

**PR F9.2 — Existing email-account flows.** After the Google-first foundation, implement email login/registration, verification/resend, and the existing change-email flow. Use the actual backend contract and address a concrete authorization defect if one blocks the flow. Do not silently link different existing accounts.

**Done:** existing eligible web accounts can access their data through supported login paths, and settings work on both device families. **Learning:** form state, callback/deep-link handling, account lifecycle.

Password reset/recovery, account deletion, and any additional release-required sign-in option are tracked in R1; this inventory did not establish those complete backend endpoints. They cannot be faked by deleting only local data.

### F10 — Finish parity and active-session freshness

**PR F10.1 — Cross-feature walkthrough and freshness.** Reconcile on launch/foreground/pull-to-refresh and after writes for every implemented feature. Audit the inventory with normal and admin accounts, on iPhone and iPad. Add SSE only if measured foreground behavior requires it; otherwise use bounded active-screen refresh and explicitly record that implementation choice.

**Done:** every inventory row has evidence of a working native equivalent or a clearly named deferred/blocked dependency. An unavailable feature is not a completed feature. Create a short missing-work list and finish actual omissions before declaring the feature pass complete.

**Learning:** integration across features and release scoping. **Defer:** unlimited background polling, general outbox, event replay infrastructure, and unnecessary backend scaling work.

## 6. Architecture rules for the feature pass

Keep SwiftUI + Observation + feature-based MVVM + repositories. Continue using the existing APIClient, Keychain credentials, and account-scoped storage. Do not switch to VIPER, introduce a dependency-injection framework, or make every folder a Swift package.

Add `Features/Capture`, `Reminders`, `Knowledge`, `Family`, and `Settings` when each feature needs them. Organizer remains responsible for item display/actions. Calendar and media adapters should be small, injected helpers owned by the feature that uses them. A shared item detail/editor can be opened from Capture, Ask, and Family where authorization allows it.

Extract reusable code after a second concrete need appears. Keep DTOs near their API adapter. Let the view model own meaningful screen state; don't put API calls directly into a growing RootView. Add navigation structure as destinations become real, not a huge up-front coordinator system.

## 7. Definition of done and review stop rule

A feature PR is ready when:

1. Its stated user workflow works with the real contract; no production action returns fake success.
2. A focused success test and meaningful validation/failure tests cover its new behavior; existing CI passes.
3. The ordinary workflow is manually checked on iPhone and iPad. Platform-only checks are labeled pending when unavailable.
4. Errors do not silently discard entered data or claim a save that failed.
5. Relevant auth/role/data-preservation boundaries remain intact.
6. The report explains changed files, the flow, tests actually run, and a small deferred list.

Reviewer decision: **ready**, **ready with deferred improvements**, or **blocked by a named defect**. A blocker needs a concrete trigger, impact, and smallest fix. No requests for broad refactoring or speculative exhaustive tests just because a better design is imaginable. After a blocker is fixed, recheck that behavior and relevant regressions; do not expand into unrelated audits.

There is no required test-count target. Existing CI is not removed for speed. Routine documentation is a short PR description and learning walkthrough, not a new design document for every feature. Keep one backlog, using this file or the existing issue tracker, with trigger/impact and later milestone.

Do not commit/push/open or merge a PR until the user requests the relevant action. Each approved feature uses a branch and focused PR; don't bundle all remaining features into one branch. A backend prerequisite gets its own paired PR only where needed, with deployment ordering stated. Never fake an absent API to check off a roadmap row.

## 8. Improvement pass after feature implementation

| Milestone | Scope | Why it waits / completion evidence |
|---|---|---|
| H1 — Correctness and resilience | Deferred cache/draft issues, ambiguous-write reconciliation, concrete duplicate-submission risks, better conflict UX, expiry consistency | Work from actual feature bugs and measurements. Add deterministic regression tests for fixed failures. |
| H2 — Scale and synchronization | Pagination/search scope, performance profiling, active-session SSE, storage migrations, optional offline outbox | Only build queues/delta sync if demonstrated usage needs them. Offline writes are not automatically required for web parity. |
| H3 — UX and accessibility | Consistent design, keyboard/VoiceOver/Dynamic Type review, iPad refinement, useful animations, localization plan | All core workflows exist, allowing consistent cross-feature improvements. |
| R1 — Platform and release completion | Real APNs/device registration, physical-device tests, any required account deletion/recovery and login integration, privacy/permission disclosures, signing, TestFlight and App Store readiness | Resolve Apple setup when user resumes it. Recheck current Apple policies/docs here. A placeholder transport is never delivery evidence. |
| N1 — Optional native additions | Share extension, widgets, Shortcuts/App Intents, camera/live recording, drag/drop, multiwindow | These extend the web experience and do not block the agreed web-feature pass. |

No claim of full native reminder parity while APNs remains blocked. No public release until applicable R1 requirements are actually met. Security/privacy fixes tied to an exposed feature belong to that feature even though the broader review happens later.

## 9. Handoff instructions for ChatGPT web

Upload this document, the master guide, and the learning guide. Upload the current diff/source as needed: private GitHub access and local uncommitted files are not automatically available in a new web chat. Never attach `.env` secrets, session cookies, Keychain exports, or personal account dumps.

Paste this prompt:

```text
You are my LifeLoop iOS feature implementation planner and reviewer.

Follow the attached LifeLoop_iOS_Feature_First_Roadmap.md as the current
execution order. It supersedes the older master guide's sequencing.
My priorities are to finish web-feature equivalents in small native PRs,
learn from the code, then improve edge cases and polish in a later pass.

Use SwiftUI, Observation, feature MVVM, and the existing repositories.
Keep code simple. Do not propose an architecture rewrite or an exhaustive
hardening program before the next feature. Preserve account isolation,
honest save results, existing revision protection, and entered user data.

Your job is to produce one focused coding-agent execution prompt at a
time and review the returned diff/report. Do not assume you can read
my filesystem or uncommitted work. Ask for the relevant source/diff
when necessary. Inspect current contracts instead of inventing endpoints.

First determine whether F0 title-editing work has been completed or
merged since this handoff. If not, review the supplied diff and prepare
only the bounded F0 closeout. If it is complete, start F1.1. Do not
restart Google sign-in, the project foundation, or the backend revision PR.

For each increment provide:
1. User-visible outcome and branch suggestion.
2. Existing code/contracts to inspect and files likely to change.
3. A concrete, small implementation sequence with simple explanations.
4. Essential tests and iPhone/iPad manual checks.
5. Explicitly deferred improvements and a clear stopping point.
6. Requested implementation report: files, behavior walkthrough,
   validation evidence, limitations, and remaining acceptance items.

Review as ready / ready with deferred improvements / blocked by a
specific defect. Every blocker needs a concrete trigger, user impact,
and smallest correction. Don't reopen unrelated details after checks pass.

Google remains the current login path; email parity comes at F9.
Apple signing is deferred. Track APNs/platform checks as pending, not done.
Keep admin-only web features restricted. Do not send messages/invitations
to real people while testing; use approved dedicated accounts.

Do not commit, push, merge, deploy, or publish unless I explicitly ask.
Do not mark a roadmap step complete based only on generated code or a
claimed test report. Distinguish source review, reported evidence, and
checks you independently verified.
```

### Reusable coding-agent execution prompt

```text
Implement [F-ID and feature] from docs/LifeLoop_iOS_Feature_First_Roadmap.md.

Repositories:
/Users/johnsonelangbam/Projects/LifeLoop-iOS
/Users/johnsonelangbam/Projects/LifeLoop (read contract/source as needed)

Inspect AGENTS.md, current branch/status, existing implementations, and the
actual web flow/API. Preserve user changes. Use one feature branch. Do not
reset, discard changes, or rebuild completed features.

Outcome: [one user workflow]
Scope: [required screens/actions and existing endpoints]
Acceptance: [observable successful behavior and essential failure behavior]
Deferred: [named nonblocking improvements]

Implement UI → view model → repository → real API end to end. Reuse the
existing architecture. Keep controls honest when a contract/platform
dependency is unavailable. Do not silently broaden backend scope.

Run focused meaningful tests and the repository's required checks. Provide
manual iPhone/iPad steps and clearly label any checks not executed. Stop
when acceptance passes; don't start unrelated refactoring or perfection work.

Return changed files, a simple learning walkthrough, exact validation
results, and deferred issues. Do not commit, push, merge, or deploy.
```

## 10. Minimal progress record

Update this table after each review, without inventing completion dates or check results.

| Milestone | Status at handoff | Next evidence |
|---|---|---|
| F0 | Local implementation in progress; documentation pushed | Bounded closeout diff, tests, normal/conflict walkthrough |
| F1–F3 | Planned | Organizer actions, capture loop, daily organization PRs |
| F4–F5 | Planned | Reminder management and calendar workflows |
| F6–F7 | Planned | Authorized media, knowledge, and Ask workflows |
| F8–F9 | Planned | Family and remaining account/appearance parity |
| F10 | Planned | Inventory walkthrough with normal/admin accounts |
| H1–H3 | Later | Prioritized improvements grounded in observed behavior |
| R1 | Later; Apple setup deferred | Platform/account/release requirements verified |
| N1 | Optional | User-selected native enhancements |

The next action is **F0 closeout, then F1.1**. Finish a useful feature, learn its implementation, review it, and move forward.
