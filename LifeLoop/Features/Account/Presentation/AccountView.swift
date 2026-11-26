import SwiftUI
import SwiftData

struct AccountView: View {
    @State private var viewModel: AccountViewModel
    @State private var googleSignIn: GoogleSignInService
    @State private var signInTask: Task<Void, Never>?
    private let server: URL
    private let container: Result<ModelContainer, Error>
    private let itemRepository: any ItemRepository
    private let captureRepository: any CaptureRepository

    init(accountRepository: any AccountRepository, itemRepository: any ItemRepository, captureRepository: any CaptureRepository, server: URL, container: Result<ModelContainer, Error>) {
        self.server = server
        self.container = container
        let googleSignIn = GoogleSignInService()
        self.googleSignIn = googleSignIn
        self.viewModel = AccountViewModel(repository: accountRepository, googleIdentity: googleSignIn)
        self.itemRepository = itemRepository
        self.captureRepository = captureRepository
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .restoring:
                ProgressView("Restoring your session…")
            case .signedOut:
                signInForm
            case .signedIn(let account):
                ConnectedOrganizerView(account: account, server: server, container: container,
                                       remote: itemRepository, captureRepository: captureRepository,
                                       onSignOut: { viewModel.signOut() },
                                       onSessionExpired: { viewModel.handleUnauthorized() })
                    .id(account.id)

            }
        }
        .task { await viewModel.restore() }
        .onDisappear { signInTask?.cancel() }
    }

    private var signInForm: some View {
        GoogleSignInWelcomeView(isBusy: viewModel.isBusy, errorMessage: viewModel.errorMessage) {
            signInTask = Task { await viewModel.signInWithGoogle() }
        }
        .background(GooglePresentationAnchor { controller in
            googleSignIn.presentingViewController = controller
        })
    }
}
