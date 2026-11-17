# LifeLoop iOS

Native iPhone/iPad client. SwiftUI + Observation, feature MVVM, repository boundaries, Swift 6. Minimum iOS/iPadOS 17.6.

## Run without signing

Open `LifeLoop/LifeLoop.xcodeproj` and choose the shared **LifeLoop** scheme. Run currently uses **Staging**, pointing to the configured server. For offline demo mode, select **Product → Scheme → Edit Scheme → Run → Info → Build Configuration → Debug**, then run on an iPhone or iPad simulator. Debug uses deterministic demo items; saved demo items reset on restart, while unsaved title drafts are recovered. Cancel discards a draft; successful Save removes it. The UI labels demo data explicitly.

Run the same suite as CI from the repository root:

```sh
scripts/test-ios.sh
DEVICE_FAMILY=iPad scripts/test-ios.sh
```

Set `SIMULATOR_ID` to choose a specific installed device. Signing, provisioning, TestFlight, and App Store distribution are deferred by request. GitHub Actions runs on branch pushes, pull requests, and manual dispatches using Xcode 26.6 on macOS 26. Separate iPhone/iPad jobs run unit, contract, and UI tests in Debug with fake auth/HTTP providers. A third job builds Staging and Release for the simulator without launching either. CI does not sign into Google, contact the configured LifeLoop server, or need signing secrets. Test results and build logs are uploaded for seven days. Swift packages use the checked-in `Package.resolved`.

## Read the code in this order

1. `App/LifeLoopApp.swift` and `App/Configuration/AppComposition.swift`: choose the environment and construct services.
2. `App/RootView.swift`: own navigation and the active full-screen editor across layout changes.
3. `Features/Organizer/Presentation`: render items and edit a local draft; asynchronous Save updates the repository and ViewModel, Cancel discards the draft. Demo complete/reopen/delete actions and refresh are supported; demo repository changes survive refresh but not process restart.
4. `Features/Organizer/Domain`: values and the item-reading contract.
5. `Features/Account`: account state, Google sign-in, and Keychain credentials.
6. `App/Networking/APIClient.swift` and `Features/Organizer/Data`: cookie requests, HTTP failures, and mapping the web API into domain values.
7. `LifeLoopTests` and `LifeLoopUITests`: behavior and failure-path examples.

## Environments and current integration limits

- **Debug / Demo.xcconfig:** sample data, no backend requests.
- **Staging / Staging.xcconfig:** requires a verified HTTPS server URL.
- **Release / Production.xcconfig:** requires a verified HTTPS production URL; currently unconfigured.

Set `LIFELOOP_API_BASE_URL` to the server origin (without `/api/v1`). In an xcconfig, escape the URL's slashes using `https:/$()/your-host.example`. Never place passwords, client secrets, or private provider keys in these files. Google OAuth client IDs are public configuration. A missing/invalid connected URL displays a configuration error, not demo data.

The Staging configuration points to the supplied server, and the developer reports successful live Google login. A separate isolated staging environment has not been confirmed. Connected mode implements **Google-only registration/sign-in, session restoration, local sign-out, and read-only items**, based on inspection of the web repository's `main` auth/items routes and database schema on 2026-11-16, with the Google route rechecked on 2026-11-17. Contract tests use synthetic responses derived from that source; they are not live-backend evidence. Unknown item statuses/types and metadata are retained.

The backend currently accepts a `session` cookie. The Google ID token is exchanged for a LifeLoop session; the session credential is kept in a per-server Keychain entry. Requests never use shared cookies or disk HTTP caching. Logout invalidates pending responses. The inspected server's logout does not revoke its JWT; server revocation remains a prerequisite for the agreed production session contract.

Connected editing is intentionally unavailable until the backend supports and verifies stale-write preconditions. Live Google account compatibility, additional provider linking, recovery/deletion, shared-item compatibility and full conflict resolution remain Phase 2 work. Email/password and Apple sign-in are outside the current Google-only increment. They are not represented by success-returning stubs.

## Execution checkpoint

- Phase 1: adaptive list/detail/edit, root-owned full-screen editor, accessibility improvements, deterministic fixtures, unit/UI automation, shared scheme, environment configs, and CI workflow implemented.
- Phase 1 validation still needs oldest-supported-OS testing and a physical-device VoiceOver/window-resizing pass; only the installed current simulator runtime is available here.
- Phase 2: read-only connection foundation implemented; live staging validation and the remaining features above are outstanding.
- Phases 3–10 remain in the master guide. Backend prerequisites are not bypassed to expose incomplete features.
- Signing/distribution are on hold and do not block local implementation.

The authoritative roadmap is `docs/LifeLoop_iOS_Final_Master_Guide_v2.0.md`. Source behavior must be rechecked before enabling writes, captures, APNs, media, Ask, or shared mutations.

## Phase 2 persistence checkpoint

Personal-item snapshots and title drafts use a version-one SwiftData store, keyed by server and account. No shared items are persisted. Offline reads are allowed only for connection failures, with a saved-time banner. HTTP authorization failures and TLS failures never use cache fallback. An offline cold start requires a previously verified active account and an unexpired credential in Keychain; server revocation cannot be detected while disconnected.

Explicit logout purges that account's snapshots/drafts and invalidates its store before clearing credentials. Session expiry returns to sign-in and retains isolated drafts for recovery by the same account. Drafts retain their base revision and cannot be saved over a changed revision. Interactive merge/review is still outstanding. Connected mutations remain unavailable, so connected draft editing is not exposed yet; recovery can be exercised in demo mode.

Read `Features/Organizer/Persistence/AccountLocalStore.swift`, `Data/CachedItemRepository.swift`, and their tests for the persistence flow. Storage errors are surfaced rather than deleting or silently recreating data. Tests use isolated memory stores and a temporary disk store, never a real account database.

## Google sign-in setup and code walkthrough

The native app now uses Google's official `GoogleSignIn` and `GoogleSignInSwift` Swift packages (9.0.0). The backend's `POST /api/v1/auth/google` handles both new and existing users; there is no separate native registration request. It accepts `{credential: <Google ID token>, timezone: <device time zone>}`, verifies the token against its `GOOGLE_CLIENT_ID`, and returns the existing account format plus a LifeLoop `session` cookie. The app only enters the organizer after validating that response and storing the session successfully.

The supplied public iOS/Web client IDs and reversed callback scheme are configured in Demo, Staging, and Production. The iOS OAuth client is confirmed to use `com.johnson.LifeLoop`. The Staging API URL is configured; the Production API URL remains unset.

Before a real-account test:

1. Verify that `LIFELOOP_API_BASE_URL` in `LifeLoop/Configuration/Staging.xcconfig` points to the intended test server before testing with real accounts.
2. Keep the Google **iOS OAuth client** bundle ID aligned with `com.johnson.LifeLoop`. Its public client ID is already set in `GOOGLE_IOS_CLIENT_ID`.
3. Verify that the staging backend's `GOOGLE_CLIENT_ID` matches the configured `GOOGLE_SERVER_CLIENT_ID` (**Web OAuth client ID**). This is the token audience the backend expects; it is different from the iOS client ID.
4. The configured `GOOGLE_REVERSED_CLIENT_ID` is the iOS client's reversed ID (`123-example.apps.googleusercontent.com` becomes `com.googleusercontent.apps.123-example`). The app registers this URL scheme so Google's browser flow can return to it. Add your test account to Google's consent-screen test users if the OAuth project is in testing mode.
5. In Xcode, use **Product → Scheme → Edit Scheme → Run → Info → Build Configuration → Staging**, then run on an iPhone/iPad simulator. Restore Debug to return to demo mode. Production still needs its verified API URL before use; configure separate OAuth IDs if that backend uses a different Google project.

For connected simulator runs, keep Xcode's normal local simulator signing enabled. A completely unsigned (`CODE_SIGNING_ALLOWED=NO`) smoke build produced a Keychain restoration error; the same build with a local ad-hoc signature opened cleanly on both devices. This does not require Apple Developer provisioning or distribution signing.

Client IDs and the callback scheme are public values; no client secret belongs in the iOS app. Missing or inconsistent OAuth settings produce a visible configuration error before opening Google. Default Debug still opens demo data. To inspect the sign-in UI immediately without a backend, open `GoogleSignInWelcomeView.swift` and use its three Xcode previews (normal, busy, failure); preview buttons deliberately do not authenticate.

Read this flow in order:

1. `GoogleSignInWelcomeView` displays Google's button and forwards a tap to `AccountView`.
2. `AccountViewModel.signInWithGoogle()` asks the injected `GoogleIdentityProvider` for an ID token. Its busy state prevents duplicate sign-in requests; cancellation leaves the screen available without an error.
3. `GoogleSignInService` is the only adapter that performs Google SDK authentication. `GooglePresentationAnchor` supplies a UIKit controller from the current SwiftUI window, including on iPad. `LifeLoopApp.onOpenURL` forwards the callback to the SDK.
4. `APIAccountRepository.signIn(googleIDToken:)` exchanges the token for a LifeLoop account and session through the existing HTTPS client. Google completing successfully alone never grants access to LifeLoop.
5. `AccountViewModel` publishes `.signedIn(account)` and `AccountView` displays the account-scoped organizer. Restart uses the saved LifeLoop session; explicit local sign-out clears both the LifeLoop credential and Google's SDK session. It does not revoke the backend JWT or disconnect the Google account.

Tests cover the request body/route, session-cookie requirement, inactive accounts, token forwarding, cancellation, duplicate taps, late results, restoration, and OAuth configuration. They use fake providers/transports, not a live Google account. Successful live Google login has been reported by the developer. New-account registration, existing web-account identity/data preservation, Google browser return on both devices, and relaunch/sign-out still need their full live walkthrough.

References: [Google iOS setup](https://developers.google.com/identity/sign-in/ios/start-integrating), [SwiftUI sign-in](https://developers.google.com/identity/sign-in/ios/sign-in), [backend ID-token authentication](https://developers.google.com/identity/sign-in/ios/backend-auth).
