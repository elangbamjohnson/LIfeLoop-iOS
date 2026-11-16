# LifeLoop iOS

Native iPhone/iPad client. SwiftUI + Observation, feature MVVM, repository boundaries, Swift 6. Minimum iOS/iPadOS 17.6.

## Run without signing

Open `LifeLoop/LifeLoop.xcodeproj`, choose the shared **LifeLoop** scheme, and run on an iPhone or iPad simulator. Debug uses deterministic demo items; edits last for the current process only. The UI labels this explicitly.

Run the same suite as CI from the repository root:

```sh
scripts/test-ios.sh
DEVICE_FAMILY=iPad scripts/test-ios.sh
```

Set `SIMULATOR_ID` to choose a specific installed device. Signing, provisioning, TestFlight, and App Store distribution are deferred by request. GitHub Actions is configured for Xcode 26.6 on macOS 26, with separate iPhone/iPad jobs; its first hosted run is pending a push.

## Read the code in this order

1. `App/LifeLoopApp.swift` and `App/Configuration/AppComposition.swift`: choose the environment and construct services.
2. `App/RootView.swift`: own navigation and the active full-screen editor across layout changes.
3. `Features/Organizer/Presentation`: render items and edit a local draft; asynchronous Save updates the repository and ViewModel, Cancel discards the draft. Demo complete/reopen/delete actions and refresh are supported; demo repository changes survive refresh but not process restart.
4. `Features/Organizer/Domain`: values and the item-reading contract.
5. `Features/Account`: account state, email sign-in, and Keychain credentials.
6. `App/Networking/APIClient.swift` and `Features/Organizer/Data`: cookie requests, HTTP failures, and mapping the web API into domain values.
7. `LifeLoopTests` and `LifeLoopUITests`: behavior and failure-path examples.

## Environments and current integration limits

- **Debug / Demo.xcconfig:** sample data, no backend requests.
- **Staging / Staging.xcconfig:** requires a verified HTTPS server URL.
- **Release / Production.xcconfig:** requires a verified HTTPS production URL; currently unconfigured.

Set `LIFELOOP_API_BASE_URL` to the server origin (without `/api/v1`). In an xcconfig, escape the URL's slashes using `https:/$()/your-host.example`. Never place credentials or provider keys in these files. A missing/invalid connected URL displays a configuration error, not demo data.

Staging does not exist yet. Connected mode implements **email/password sign-in, session restoration, local sign-out, and read-only items**, based on inspection of the web repository's `main` auth/items routes and database schema on 2026-11-16. Contract tests use synthetic responses derived from that source; they are not live-backend evidence. Unknown item statuses/types and metadata are retained.

The backend currently accepts a `session` cookie. Passwords are not persisted; the session credential is kept in a per-server Keychain entry. Requests never use shared cookies or disk HTTP caching. Logout invalidates pending responses. The inspected server's logout does not revoke its JWT; server revocation remains a prerequisite for the agreed production session contract.

Connected editing is intentionally unavailable until the backend supports and verifies stale-write preconditions. Google/Apple identity linking, registration/verification UI, recovery/deletion, cache/draft persistence, shared-item compatibility, and live session-expiry handling remain Phase 2 work. They are not represented by success-returning stubs.

## Execution checkpoint

- Phase 1: adaptive list/detail/edit, root-owned full-screen editor, accessibility improvements, deterministic fixtures, unit/UI automation, shared scheme, environment configs, and CI workflow implemented.
- Phase 1 validation still needs oldest-supported-OS testing and a physical-device VoiceOver/window-resizing pass; only the installed current simulator runtime is available here.
- Phase 2: read-only connection foundation implemented; live staging validation and the remaining features above are outstanding.
- Phases 3–10 remain in the master guide. Backend prerequisites are not bypassed to expose incomplete features.
- Signing/distribution are on hold and do not block local implementation.

The authoritative roadmap is `docs/LifeLoop_iOS_Final_Master_Guide_v2.0.md`. Source behavior must be rechecked before enabling writes, captures, APNs, media, Ask, or shared mutations.
