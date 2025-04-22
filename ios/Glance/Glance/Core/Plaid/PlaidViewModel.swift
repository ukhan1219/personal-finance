import SwiftUI
import LinkKit // Import Plaid LinkKit SDK
import Combine // For observing notifications if needed later, and managing disposables

class PlaidViewModel: NSObject, ObservableObject { // Inherit from NSObject for NotificationCenter

    // MARK: - Dependencies
    private let apiService: APIService
    private weak var authViewModel: AuthViewModel? // Use weak to avoid retain cycles if passed around
    private weak var spendingViewModel: SpendingViewModel? // <-- Add weak reference

    // MARK: - Published State Properties
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    // Note: We don't publish linkSuccess directly. Instead, we trigger authViewModel.checkUserStatus()
    // on success, and the main app flow reacts to changes in authViewModel.hasConnectedBankAccount.

    // MARK: - Private Properties
    private var plaidLinkHandler: Handler?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initializer
    init(apiService: APIService, authViewModel: AuthViewModel, spendingViewModel: SpendingViewModel) {
        self.apiService = apiService
        self.authViewModel = authViewModel
        self.spendingViewModel = spendingViewModel // <-- Store the reference
        super.init()
        // setupNotificationObserver() // <-- Comment out observer setup
        print("PlaidViewModel: Initialized with SpendingViewModel reference.")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        print("PlaidViewModel: Deinitialized")
    }

    // MARK: - Notification Handling for OAuth Redirects
    /* // <-- Comment out entire section
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOAuthRedirect(notification:)),
            name: .receivedPlaidLinkRedirectURI,
            object: nil
        )
        print("PlaidViewModel: Notification observer setup for Plaid OAuth redirects.")
    }

    @objc private func handleOAuthRedirect(notification: Notification) {
        guard let url = notification.object as? URL else {
            print("PlaidViewModel: Received redirect notification but failed to get URL.")
            return
        }
        print("PlaidViewModel: Handling OAuth redirect URL: \\(url.absoluteString)")
        // Correct way to handle OAuth redirect: Call continue(from:) on Plaid.itemCreationManager
        // This assumes itemCreationManager is a static property/method on the Plaid type.
        Plaid.itemCreationManager.continue(from: url)
        print("PlaidViewModel: Called Plaid.itemCreationManager.continue(from: url)")
    }
    */ // <-- Comment out entire section

    // MARK: - Plaid Link Flow Logic

    /// Initiates the Plaid Link flow: fetches a link token, creates a configuration,
    /// creates a handler, and opens the Plaid Link UI.
    func openPlaidLink() {
        print("PlaidViewModel: Starting Plaid Link flow...")
        self.isLoading = true
        self.errorMessage = nil

        apiService.createLinkToken { [weak self] result in
            DispatchQueue.main.async { // Ensure UI updates are on main thread
                guard let self = self else { return }

                switch result {
                case .success(let linkToken):
                    print("PlaidViewModel: Successfully received link token.")
                    let configuration = self.createLinkConfiguration(linkToken: linkToken)

                    // Create the Plaid handler using the configuration
                    let createResult = Plaid.create(configuration)
                    switch createResult {
                    case .success(let handler):
                        print("PlaidViewModel: Successfully created Plaid Link handler.")
                        self.plaidLinkHandler = handler
                        self.presentPlaidLink(handler: handler)
                        // isLoading remains true while Link is presented
                    case .failure(let error):
                        print("PlaidViewModel: Error creating Plaid Link handler: \\(error.localizedDescription)")
                        self.errorMessage = "Failed to initialize Plaid Link. Please try again. (Error: \\(error.localizedDescription))"
                        self.isLoading = false
                    }

                case .failure(let error):
                    print("PlaidViewModel: Error fetching link token: \\(error.localizedDescription)")
                    self.errorMessage = "Failed to fetch Plaid Link token. Please try again. (Error: \\(error.localizedDescription))"
                    self.isLoading = false
                }
            }
        }
    }

    /// Creates the LinkTokenConfiguration needed to initialize Plaid Link.
    private func createLinkConfiguration(linkToken: String) -> LinkTokenConfiguration {
        var config = LinkTokenConfiguration(token: linkToken) { [weak self] success in
            // --- onSuccess Closure ---
            print("PlaidViewModel: Plaid Link onSuccess - Public Token: \\(success.publicToken)")
            self?.exchangePublicToken(publicToken: success.publicToken)
            // isLoading state will be handled by exchangePublicToken
            // Close the Plaid Link UI (handled automatically by LinkKit)
        }

        config.onExit = { [weak self] exit in
            // --- onExit Closure ---
            DispatchQueue.main.async { // Ensure UI updates on main thread
                 guard let self = self else { return }
                 self.isLoading = false // Stop loading on exit
                 if let error = exit.error {
                     print("PlaidViewModel: Plaid Link onExit with error: \\(error.localizedDescription)")
                     // Map Plaid error codes to user-friendly messages if desired
                     self.errorMessage = "Plaid Link exited with error: \\(error.localizedDescription)"
                 } else {
                     print("PlaidViewModel: Plaid Link exited without error (user cancelled?).")
                     // Don't necessarily show an error if the user just closed the modal
                     // self.errorMessage = "Plaid Link was cancelled."
                 }
                 self.plaidLinkHandler = nil // Clear the handler on exit
            }
        }

        config.onEvent = { event in
            // --- onEvent Closure (Optional) ---
            print("PlaidViewModel: Plaid Link onEvent: \\(event.eventName.description)")
            // Track analytics or specific UI events if needed
        }

        print("PlaidViewModel: Created LinkTokenConfiguration.")
        return config
    }

    /// Presents the Plaid Link UI using the provided handler.
    private func presentPlaidLink(handler: Handler) {
         print("PlaidViewModel: Attempting to present Plaid Link...")
         guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
             print("PlaidViewModel: Error - Could not find root view controller to present Plaid Link.")
             self.errorMessage = "Could not display Plaid Link interface."
             self.isLoading = false
             self.plaidLinkHandler = nil // Clear handler if presentation fails
             return
         }

         // Present the Plaid Link UI
         handler.open(presentUsing: .viewController(rootViewController))
         // Note: LinkKit handles the presentation modally. `isLoading` remains true conceptually
         // until the onSuccess or onExit callback occurs.
         print("PlaidViewModel: Plaid Link presentation initiated.")
     }


    /// Exchanges the public token received from Plaid Link for an access token via the backend.
    private func exchangePublicToken(publicToken: String) {
        print("PlaidViewModel: Exchanging public token...")
        // Keep isLoading true or manage a separate state if needed
        self.isLoading = true
        self.errorMessage = nil // Clear previous errors

        apiService.exchangePublicToken(publicToken: publicToken) { [weak self] result in
            DispatchQueue.main.async { // Ensure UI updates on main thread
                guard let self = self else { return }

                switch result {
                case .success:
                    print("PlaidViewModel: Successfully exchanged public token via backend.")
                    // --- Clear the spending cache to force refresh ---
                    print("PlaidViewModel: Clearing spending cache...")
                    self.spendingViewModel?.clearCache() // <-- Add this call

                    // Trigger the AuthViewModel to re-check the user's status from the backend.
                    // This will update `hasConnectedBankAccount` and cause the UI flow in GlanceApp to change.
                    self.authViewModel?.checkUserStatus()
                    // Let the checkUserStatus manage the final isLoading state in AuthViewModel
                    // We can set our own isLoading to false here, as the exchange is done.
                    self.isLoading = false
                    self.plaidLinkHandler = nil // Clear handler on success

                case .failure(let error):
                    print("PlaidViewModel: Error exchanging public token: \\(error.localizedDescription)")
                    self.errorMessage = "Failed to save bank connection. Please try again. (Error: \\(error.localizedDescription))"
                    self.isLoading = false
                    self.plaidLinkHandler = nil // Clear handler on failure
                }
            }
        }
    }
}
