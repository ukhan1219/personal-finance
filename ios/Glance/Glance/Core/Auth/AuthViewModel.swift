import Foundation
import Combine
import FirebaseAuth // For Firebase Auth
import FirebaseCore // Often needed alongside FirebaseAuth
import GoogleSignIn // For Google Sign-In logic
import UIKit // Needed for getting the root view controller
import SwiftUI
import CryptoKit
import AuthenticationServices

class AuthViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var user: User? // Firebase User object
    @Published var isAuthenticated: Bool = false
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false // General loading state
    @Published var isCheckingStatus: Bool = false // Specific state for status check
    @Published var hasConnectedBankAccount: Bool = false // The status flag
    @Published var passwordResetSent: Bool = false // Add a published property to signal success for showing an alert

    // MARK: - Private Properties
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    private let userDefaults = UserDefaults.standard // For caching
    private let userDefaultsStatusKey = "hasConnectedBankAccount" // UserDefaults key

    // Dependency: APIService (Injected)
    private var apiService: APIService!

    // MARK: - Initializer & Setup
    override init() {
        super.init()
        // Initial state from Firebase Auth
        self.user = Auth.auth().currentUser
        self.isAuthenticated = (self.user != nil)

        // Initial state from cache (only if authenticated initially)
        if self.isAuthenticated {
            self.hasConnectedBankAccount = userDefaults.bool(forKey: userDefaultsStatusKey)
            print("AuthViewModel Init: Initial cached status read = \(self.hasConnectedBankAccount)")
        } else {
            print("AuthViewModel Init: User not authenticated, initial status defaults to false.")
        }

        // APIService is now injected via setupAPIService()
        // self.apiService = APIService(authViewModel: self) // <-- REMOVE THIS

        registerAuthStateHandler()

        // Status check will be triggered by setupAPIService or registerAuthStateHandler
        // if self.isAuthenticated {
        //     checkUserStatus()
        // }
    }

    // Method for proper injection (call this after AuthViewModel is created)
    func setupAPIService(apiService: APIService) {
        print("AuthViewModel: Setting up APIService...")
        self.apiService = apiService
        // Now that APIService is set up, check status if needed
        if self.isAuthenticated {
            print("AuthViewModel: APIService setup, triggering initial status check.")
            checkUserStatus()
        }
    }

    deinit {
        if let handle = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // Keep the existing auth state listener from the overview.md example
    func registerAuthStateHandler() {
        // Detach previous listener if exists
        if let handle = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        // Attach new listener
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            DispatchQueue.main.async { // Ensure UI updates are on main thread
                guard let self = self else { return }
                let wasAuthenticated = self.isAuthenticated
                self.user = user
                self.isAuthenticated = (user != nil)

                if user != nil {
                    print("Auth State Changed: SIGNED IN (UID: \(user!.uid))")
                    if !wasAuthenticated {
                        print("   -> Event: User just logged in. Triggering status check.")
                        self.checkUserStatus() // Check status on new login
                    }
                } else {
                    print("Auth State Changed: SIGNED OUT.")
                    if wasAuthenticated {
                        print("   -> Event: User just logged out. Clearing status cache.")
                        // Reset status on logout
                        self.hasConnectedBankAccount = false
                        self.userDefaults.removeObject(forKey: self.userDefaultsStatusKey)
                    }
                }
            }
        }
    }

    // MARK: - User Status Check

    func checkUserStatus() {
        guard isAuthenticated else {
            print("checkUserStatus: Not checking status, user not authenticated.")
            return
        }

        // 1. Read from UserDefaults immediately (redundant if done in init/handler, but safe)
        let cachedStatus = userDefaults.bool(forKey: userDefaultsStatusKey)
        print("checkUserStatus: Read cached status = \(cachedStatus)")
        if self.hasConnectedBankAccount != cachedStatus {
             print("checkUserStatus: Updating state from cache: \(cachedStatus)")
             self.hasConnectedBankAccount = cachedStatus
        }

        // 2. Start background check
        guard !isCheckingStatus else {
            print("checkUserStatus: Already checking status.")
            return
        } // Prevent concurrent checks
        print("checkUserStatus: Starting background check via API call...")
        isCheckingStatus = true

        // Ensure apiService is available
        guard apiService != nil else {
            print("checkUserStatus: Error - APIService not initialized!")
            isCheckingStatus = false
            return
        }

        apiService.fetchUserStatus { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isCheckingStatus = false
                switch result {
                case .success(let status):
                    print("checkUserStatus: Background check successful. Fetched Status = \(status)")
                    // Update published property *and* UserDefaults if changed
                    if self.hasConnectedBankAccount != status {
                        self.hasConnectedBankAccount = status
                        self.userDefaults.set(status, forKey: self.userDefaultsStatusKey)
                        print("checkUserStatus: Updated state AND cache to \(status).")
                    } else {
                         print("checkUserStatus: Fetched status (\(status)) matches current state. No update needed.")
                    }
                case .failure(let error):
                    // Handle error appropriately (log, show alert?)
                    print("checkUserStatus: Background check failed: \(error.localizedDescription)")
                    // Optional: Decide if you want to reset hasConnectedBankAccount to false on error
                    // self.hasConnectedBankAccount = false
                    // self.userDefaults.set(false, forKey: self.userDefaultsStatusKey)
                }
            }
        }
    }

    // MARK: - Authentication Methods

    // --- Get ID Token (Needed by APIService) ---
    func getIDToken(completion: @escaping (String?) -> Void) {
        user?.getIDTokenResult(forcingRefresh: false) { result, error in // Don't force refresh unless needed
            DispatchQueue.main.async {
                if let error = error {
                    print("Error getting ID token: \(error)")
                    // Handle specific errors? e.g., network error
                    self.errorMessage = "Could not verify session. Please try again." // Example error message
                    completion(nil)
                    return
                }
                print("Successfully retrieved ID token.")
                completion(result?.token)
            }
        }
    }

    // --- Email/Password Sign Up ---
    func signUp(email: String, pass: String) {
        isLoading = true
        errorMessage = nil
        print("Attempting to sign up with email: \(email)")

        Auth.auth().createUser(withEmail: email, password: pass) { [weak self] (result, error) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Sign up failed: \(error.localizedDescription)"
                    print("Sign up error: \(error.localizedDescription)")
                } else {
                    self.errorMessage = nil
                    let userId = result?.user.uid ?? "N/A"
                    print("Sign up successful and user automatically signed in.")
                    print("   -> Firebase User UID: \(userId)")
                    print("   -> Use this UID ('\(userId)') to create/reference user data in Firestore (e.g., /users/\(userId))")
                    // The authStateHandler will update isAuthenticated.
                }
            }
        }
    }

    // --- Email/Password Sign In ---
    func signIn(email: String, pass: String) {
        isLoading = true
        errorMessage = nil
        print("Attempting to sign in with email...")

        Auth.auth().signIn(withEmail: email, password: pass) { [weak self] (result, error) in
            DispatchQueue.main.async { // Ensure UI updates are on main thread
                guard let self = self else { return }
                self.isLoading = false // Stop loading indicator

                if let error = error {
                    self.errorMessage = self.mapFirebaseError(error) // Use helper for better messages
                    print("Sign in error: \(error.localizedDescription)")
                    // isAuthenticated remains false due to listener
                } else {
                    self.errorMessage = nil // Clear any previous errors
                    let userId = result?.user.uid ?? "N/A"
                    print("Sign in successful via email.")
                    print("   -> Firebase User UID: \(userId)")
                    print("   -> Use this UID ('\(userId)') to fetch/reference user data in Firestore (e.g., /users/\(userId), /plaidItems where userId == '\(userId)')")
                    // isAuthenticated will be updated to true by the authStateHandler
                }
            }
        }
    }

    // --- Password Reset ---
    func sendPasswordReset(email: String) {
        // Basic email validation
        guard !email.isEmpty, email.contains("@") else {
            self.errorMessage = "Please enter a valid email address."
            return
        }

        isLoading = true
        errorMessage = nil
        passwordResetSent = false // Reset flag
        print("Attempting to send password reset email to: \(email)")

        // Set language code if needed (example using device default)
        Auth.auth().useAppLanguage()

        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                if let error = error {
                    self.errorMessage = self.mapFirebaseError(error) // Use helper for consistency
                    print("Password reset error: \(error.localizedDescription)")
                } else {
                    self.errorMessage = nil
                    self.passwordResetSent = true // Signal success
                    print("Password reset email sent successfully to \(email).")
                    // UI should show an alert based on passwordResetSent
                }
            }
        }
    }

    // --- Google Sign-In Logic ---
    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        print("Attempting Google Sign-In...")

        // 1. Get Client ID from Firebase options
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            handleSignInError(message: "Google Sign-In client ID not found in Firebase options.")
            return
        }

        // 2. Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // 3. Get root view controller to present Google Sign-In flow
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            handleSignInError(message: "Could not find root view controller to present Google Sign-In.")
            print("Could not get root view controller.")
            return
        }

        // 4. Start the sign in flow!
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            DispatchQueue.main.async { // Ensure UI updates are on main thread
                guard let self = self else { return }

                if let error = error {
                    self.handleSignInError(message: "Google Sign-In failed: \(error.localizedDescription)")
                    return
                }

                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString
                else {
                    self.handleSignInError(message: "Google Sign-In succeeded but failed to get ID token.")
                    return
                }

                let accessToken = user.accessToken.tokenString // Might need this for backend linking later? Usually just ID token for Firebase Auth.

                // 5. Create Firebase credential
                let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                             accessToken: accessToken)

                // 6. Sign in with Firebase
                print("Google Sign-In successful, attempting Firebase sign in...")
                Auth.auth().signIn(with: credential) { authResult, error in
                     self.isLoading = false // Final loading state update
                     if let error = error {
                         self.errorMessage = self.mapFirebaseError(error)
                         print("Firebase Sign in with Google credential failed: \(error.localizedDescription)")
                     } else {
                         self.errorMessage = nil
                         let userId = authResult?.user.uid ?? "N/A"
                         print("Firebase Sign in with Google successful.")
                         print("   -> Firebase User UID: \(userId)")
                         print("   -> Use this UID ('\(userId)') to fetch/reference user data in Firestore.")
                         // Listener will update isAuthenticated
                     }
                }
            }
        }
    }

    // Add other methods like signOut, email/password sign-in/signup later
    func signOut() {
        isLoading = true
        errorMessage = nil
        print("Attempting to sign out...")

        let firebaseAuth = Auth.auth()
        do {
            try firebaseAuth.signOut()
            // Sign out from Google as well if the user was signed in with Google
            GIDSignIn.sharedInstance.signOut()
            print("Sign out successful from Firebase (and Google if applicable).")
            // The authStateHandler will update isAuthenticated and user to nil/false
            // No need to manually set isAuthenticated = false here
        } catch let signOutError as NSError {
            self.errorMessage = "Error signing out: \(signOutError.localizedDescription)"
            print("Error signing out: %@", signOutError)
        }
        // Ensure isLoading is set to false regardless of outcome
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }

    // --- Helper Functions ---

    // Helper to handle common error setting logic for sign-in methods
    private func handleSignInError(message: String) {
         DispatchQueue.main.async {
             self.errorMessage = message
             self.isLoading = false
             print(message) // Also print the error
         }
     }

    // Helper to provide slightly more user-friendly messages for common Firebase Auth errors
    private func mapFirebaseError(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case AuthErrorCode.wrongPassword.rawValue:
            return "Incorrect password. Please try again."
        case AuthErrorCode.invalidEmail.rawValue:
            return "Invalid email format."
        case AuthErrorCode.userNotFound.rawValue:
            return "No account found with this email."
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "This email address is already in use."
        case AuthErrorCode.weakPassword.rawValue:
            return "Password is too weak. Please choose a stronger password."
        case AuthErrorCode.networkError.rawValue:
            return "Network error. Please check your connection."
        // Add more specific cases as needed
        default:
            // Generic fallback
            return "An authentication error occurred. \(nsError.localizedDescription)"
        }
    }

    // --- Placeholder for Biometrics ---
    func authenticateWithBiometrics(completion: @escaping (Bool, Error?) -> Void) {
        // TODO: Implement Biometric Auth Flow using LocalAuthentication
        print("Biometric Auth requested - Not implemented")
        completion(false, nil) // Placeholder
    }

    // MARK: - Apple Sign In Implementation

    // Call this function from your LoginView's "Sign in with Apple" button action
    func startSignInWithAppleFlow() {
        guard #available(iOS 13, *) else {
            handleSignInError(message: "Sign in with Apple requires iOS 13 or later.")
            return
        }
        isLoading = true // Start loading indicator
        errorMessage = nil
        print("Starting Sign in with Apple flow...")

        let nonce = randomNonceString()
        currentNonce = nonce // Store the nonce for validation later
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email] // Request user's name and email
        request.nonce = sha256(nonce) // Set the hashed nonce on the request

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self // Set the delegate to handle the response
        authorizationController.presentationContextProvider = self // Set the context provider for presentation
        authorizationController.performRequests() // Start the sign-in request
    }

    // MARK: - Apple Sign In Helpers

    // Adapted from https://firebase.google.com/docs/auth/ios/apple
    private func randomNonceString(length: Int = 32) -> String {
      precondition(length > 0)
      var randomBytes = [UInt8](repeating: 0, count: length)
      let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
      if errorCode != errSecSuccess {
        fatalError(
          "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
        )
      }

      let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

      let nonce = randomBytes.map { byte in
        // Pick a random character from the set, wrapping around if needed.
        charset[Int(byte) % charset.count]
      }

      return String(nonce)
    }

    @available(iOS 13, *)
    private func sha256(_ input: String) -> String {
      let inputData = Data(input.utf8)
      let hashedData = SHA256.hash(data: inputData)
      let hashString = hashedData.compactMap {
        String(format: "%02x", $0)
      }.joined()

      return hashString
    }

    // We will implement the delegate methods in the extension below next
}

// MARK: - ASAuthorizationControllerDelegate & ContextProviding

extension AuthViewModel: ASAuthorizationControllerDelegate {

    @available(iOS 13.0, *)
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("Apple Sign In authorization successful.")
        // Ensure we have the credential type we expect
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("Error: Could not cast authorization credential to ASAuthorizationAppleIDCredential.")
            handleSignInError(message: "Apple Sign In completed but credential format was unexpected.")
            return
        }

        // Retrieve the nonce we stored earlier for validation
        guard let nonce = currentNonce else {
            fatalError("Invalid state: A login callback was received, but no login request was sent (nonce missing).")
            // In a real app, you might want to handle this less fatally, perhaps showing an error.
            // handleSignInError(message: "Internal error during Apple Sign In (nonce missing).")
            // return
        }
        // Reset the nonce after retrieving it
        currentNonce = nil

        // Get the identity token from Apple
        guard let appleIDToken = appleIDCredential.identityToken else {
            print("Error: Unable to fetch identity token from Apple credential.")
            handleSignInError(message: "Could not get identity token from Apple.")
            return
        }

        // Convert the token data to a string
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("Error: Unable to serialize identity token string from data.")
            handleSignInError(message: "Could not process identity token from Apple.")
            return
        }

        // Create a Firebase credential using the ID token and raw nonce
        // IMPORTANT: Use the *raw* (unhashed) nonce here for Firebase validation
        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                        rawNonce: nonce,
                                                        fullName: appleIDCredential.fullName) // fullName may be nil

        // Sign in with Firebase using the Apple credential
        print("Attempting Firebase sign in with Apple credential...")
        Auth.auth().signIn(with: credential) { [weak self] (authResult, error) in
            guard let self = self else { return }

            DispatchQueue.main.async { // Ensure UI updates on main thread
                self.isLoading = false // Final loading state update

                if let error = error {
                    // Handle Firebase sign-in errors (e.g., invalid nonce, account already exists with different credential)
                    self.errorMessage = self.mapFirebaseError(error) // Use helper for better messages
                    print("Firebase Sign in with Apple credential failed: \(error.localizedDescription)")
                    // If error.code == .credentialAlreadyInUse, you might need to handle account linking.
                    // If error.code == .invalidCredential, check nonce implementation.
                } else {
                    self.errorMessage = nil // Clear any previous errors
                    let userId = authResult?.user.uid ?? "N/A"
                    print("Firebase Sign in with Apple successful.")
                    print("   -> Firebase User UID: \(userId)")
                    print("   -> Use this UID ('\(userId)') to fetch/reference user data in Firestore.")
                    // Update user name in Firebase profile if needed and available (only first time)
                    if let fullName = appleIDCredential.fullName, let user = authResult?.user {
                        let changeRequest = user.createProfileChangeRequest()
                        // Combine first and last names (handle potential nil values)
                        var nameComponents: [String] = []
                        if let givenName = fullName.givenName { nameComponents.append(givenName) }
                        if let familyName = fullName.familyName { nameComponents.append(familyName) }
                        if !nameComponents.isEmpty {
                             changeRequest.displayName = nameComponents.joined(separator: " ")
                             changeRequest.commitChanges { error in
                                 if let error = error {
                                     print("Error updating Firebase profile display name: \(error.localizedDescription)")
                                 } else {
                                     print("Successfully updated Firebase display name from Apple Sign In.")
                                 }
                             }
                        }
                    }
                    // The authStateHandler will update isAuthenticated
                }
            }
        }
    }

    @available(iOS 13.0, *)
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle errors from the ASAuthorizationController flow itself (e.g., user cancellation)
        let errorMessage: String
        // Check if the user cancelled the sign-in
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            errorMessage = "Sign in with Apple was cancelled."
            print(errorMessage)
            // Don't treat cancellation as a blocking error, just stop loading
            DispatchQueue.main.async {
                self.isLoading = false
                // Optionally clear any existing error message: self.errorMessage = nil
            }
        } else {
            // Handle other errors
            errorMessage = "Sign in with Apple failed: \(error.localizedDescription)"
            print(errorMessage)
            handleSignInError(message: errorMessage) // Use helper to set state
        }
         // Reset the nonce if the flow failed or was cancelled
         currentNonce = nil
    }
}

extension AuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    @available(iOS 13.0, *)
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Return the main window of the app
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
             print("Warning: Could not get key window for Apple Sign In presentation anchor. Using a new window.")
             // Returning a newly created window might not work reliably.
             // It's better to ensure a key window exists or handle the error more robustly.
             // For now, we'll stick with this, but be aware it might need refinement.
             return UIWindow()
        }
        print("Providing presentation anchor: \(window)")
        return window
    }
}
