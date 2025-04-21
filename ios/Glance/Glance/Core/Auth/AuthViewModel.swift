import Foundation
import Combine
import FirebaseAuth // For Firebase Auth
import FirebaseCore // Often needed alongside FirebaseAuth
import GoogleSignIn // For Google Sign-In logic
import UIKit // Needed for getting the root view controller
import SwiftUI
import CryptoKit
import AuthenticationServices
import LocalAuthentication // <-- IMPORT THIS

class AuthViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var user: User? // Firebase User object
    @Published var isAuthenticated: Bool = false
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false // General loading state
    @Published var isCheckingStatus: Bool = false // Specific state for status check
    @Published var hasConnectedBankAccount: Bool = false // The status flag
    @Published var passwordResetSent: Bool = false // Add a published property to signal success for showing an alert
    @Published var isEmailVerified: Bool = false // Track email verification status

    // --- NEW State for Local Biometric Lock ---
    @Published var isLocked: Bool = true

    // --- NEW State for Delete Account Flow ---
    @Published var needsReauthenticationForDelete: Bool = false // Trigger for password re-auth UI
    @Published var reauthError: String? // Specific error message for re-auth alert

    // MARK: - Private Properties
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    private let userDefaults = UserDefaults.standard // For caching
    private let userDefaultsStatusKey = "hasConnectedBankAccount" // UserDefaults key

    // --- NEW Private state for Apple delete flow ---
    private var isDeletingWithApple: Bool = false // Flag to track context in delegate methods

    // Dependency: APIService (Injected)
    private var apiService: APIService!

    // MARK: - Initializer & Setup
    override init() {
        super.init()
        // Initial state from Firebase Auth
        self.user = Auth.auth().currentUser
        self.isAuthenticated = (self.user != nil)
        self.isEmailVerified = self.user?.isEmailVerified ?? false // Initialize verification status

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
                // Update verification status whenever user changes
                self.isEmailVerified = user?.isEmailVerified ?? false

                if let user = user {
                    print("Auth State Changed: SIGNED IN (UID: \(user.uid))")
                    print("   -> Email Verified: \(self.isEmailVerified)") // Log verification status
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
                        // Also reset verification status on logout
                        self.isEmailVerified = false
                        // --- NEW: Reset delete flow state on logout ---
                        self.needsReauthenticationForDelete = false
                        self.reauthError = nil
                        self.isDeletingWithApple = false
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

                    // Send verification email
                    if let newUser = result?.user {
                         newUser.sendEmailVerification { error in
                              // Still on main thread from createUser completion
                              if let error = error {
                                   print("   -> Error sending verification email: \(error.localizedDescription)")
                                   // Optionally append to existing message or set a specific one
                                   self.errorMessage = (self.errorMessage ?? "") + " Failed to send verification email: \(error.localizedDescription)"
                              } else {
                                   print("   -> Verification email sent successfully.")
                              }
                         }
                    } else {
                         // Defensive coding: This case shouldn't happen if error is nil,
                         // but handle it just in case the result or user is unexpectedly nil.
                         print("   -> Warning: SignUp successful but user object was nil unexpectedly. Cannot send verification email.")
                         self.errorMessage = (self.errorMessage ?? "") + " Account created, but failed to send verification email."
                    }
                    // The authStateHandler will update isAuthenticated and isEmailVerified.
                    // isLoading was already set to false.
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

                // 6. Check if user is already signed in to link, otherwise sign in
                if let currentUser = Auth.auth().currentUser {
                    // User is already signed in - Link the new credential
                    print("User already signed in (\(currentUser.uid)). Attempting to link Google credential...")
                    self.isLoading = true // Ensure loading state is active
                    self.errorMessage = nil
                    currentUser.link(with: credential) { [weak self] authResult, error in
                        guard let self = self else { return }
                        DispatchQueue.main.async {
                             self.isLoading = false
                             if let error = error {
                                 self.handleLinkingError(error, providerName: "Google")
                             } else {
                                 // Linking successful
                                 self.errorMessage = nil
                                 print("Successfully linked Google account to existing user \(authResult?.user.uid ?? "N/A").")
                                 // Optionally update profile info here if needed
                             }
                        }
                    }
                } else {
                    // User is not signed in - Perform sign in
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
    }

    // Add other methods like signOut, email/password sign-in/signup later
    func signOut() {
        isLoading = true
        errorMessage = nil
        print("Attempting to sign out...")

        // --- Lock the app state before signing out ---
        self.lock()

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

    // Helper for handling errors specifically from the link(with:credential) operation
    private func handleLinkingError(_ error: Error, providerName: String) {
        let nsError = error as NSError
        if nsError.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
            self.errorMessage = "This \(providerName) account is already linked to a different Glance account. Please sign out first."
            print("Linking Error: Credential already in use for \(providerName).")
        } else {
            // Use existing mapper for other errors
            self.errorMessage = self.mapFirebaseError(error)
            print("Linking Error (\(providerName)): \(error.localizedDescription) (Code: \(nsError.code))")
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
        // --- NEW: Add case for re-authentication needed ---
        case AuthErrorCode.requiresRecentLogin.rawValue:
            return "This action requires you to have signed in recently. Please sign in again."
        // --- NEW: Add case for Apple Sign In specific errors (if needed, map from delegate) ---
        // Example:
        // case ASAuthorizationError.Code.canceled.rawValue: // Note: This might not be the correct way to map ASAuthorizationError
        //     return "Apple Sign In was cancelled."
        default:
            // Generic fallback
            return "An authentication error occurred. \(nsError.localizedDescription)"
        }
    }

    // --- Placeholder for Biometrics ---
    // func authenticateWithBiometrics(completion: @escaping (Bool, Error?) -> Void) {
    //     // TODO: Implement Biometric Auth Flow using LocalAuthentication
    //     print("Biometric Auth requested - Not implemented")
    //     completion(false, nil) // Placeholder
    // }

    // MARK: - Biometric/Local Authentication

    /// Sets the app to the locked state.
    func lock() {
        DispatchQueue.main.async {
            print("AuthViewModel: Locking app UI.")
            self.isLocked = true
        }
    }

    /// Requests biometric or passcode authentication to unlock the app.
    func requestBiometricUnlock() {
        let context = LAContext()
        var error: NSError?

        // Define the reason string for the prompt
        let reason = "Please authenticate to access your Glance data."

        // Check if the device is capable of biometric or passcode authentication
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            print("AuthViewModel: Device capable of biometric/passcode auth. Evaluating policy...")
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, authenticationError in
                // Ensure UI updates happen on the main thread
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if success {
                        print("AuthViewModel: Biometric/passcode authentication SUCCESSFUL.")
                        self.isLocked = false
                    } else {
                        // Handle authentication failure
                        print("AuthViewModel: Biometric/passcode authentication FAILED.")
                        self.isLocked = true // Ensure app remains locked
                        if let authError = authenticationError as? LAError {
                            // You could potentially handle specific errors differently
                            // e.g., user cancelled, passcode fallback, etc.
                            print("    -> LAError code: \(authError.code.rawValue) - \(authError.localizedDescription)")
                            // Optionally set an error message, but maybe not necessary as OS shows feedback
                            // self.errorMessage = "Authentication failed: \(authError.localizedDescription)"
                        } else {
                            print("    -> Unknown authentication error: \(authenticationError?.localizedDescription ?? "N/A")")
                            // self.errorMessage = "An unknown authentication error occurred."
                        }
                    }
                }
            }
        } else {
            // Device cannot use biometric/passcode authentication (e.g., no passcode set)
            print("AuthViewModel: Device NOT capable of biometric/passcode auth.")
            // What should happen here? Keep locked? Show an error?
            // For now, we'll keep it locked and log the error.
            DispatchQueue.main.async {
                 self.isLocked = true // Ensure app remains locked
                 let errorCode = error?.code ?? 0
                 let errorDesc = error?.localizedDescription ?? "Not specified"
                 print("    -> LAContext Error Code: \(errorCode) - \(errorDesc)")
                 // Maybe show an error message guiding the user to set a passcode?
                 // self.errorMessage = "Please enable Face ID, Touch ID, or a passcode on your device to secure Glance."
            }
        }
    }

    // MARK: - Apple Sign In Implementation

    // Call this function from your LoginView's "Sign in with Apple" button action
    func startSignInWithAppleFlow() {
        guard #available(iOS 13, *) else {
            handleSignInError(message: "Sign in with Apple requires iOS 13 or later.")
            return
        }
        // --- Reset deletion flag when starting normal sign-in ---
        isDeletingWithApple = false

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

    /// Updates the Firebase user's display name based on the Apple credential, if available.
    /// Should only be called after successful sign-in or linking.
    @available(iOS 13.0, *)
    private func updateNameFromAppleCredential(_ appleIDCredential: ASAuthorizationAppleIDCredential, user: FirebaseAuth.User?) {
        guard let fullName = appleIDCredential.fullName, let user = user else {
            // No name provided by Apple or user object is nil
            return
        }

        // Check if display name needs updating (avoid unnecessary writes)
        // Combine first and last names (handle potential nil values)
        var nameComponents: [String] = []
        if let givenName = fullName.givenName { nameComponents.append(givenName) }
        if let familyName = fullName.familyName { nameComponents.append(familyName) }
        let appleName = nameComponents.joined(separator: " ")

        // Only update if the name from Apple is non-empty and different from the current display name
        if !appleName.isEmpty && user.displayName != appleName {
            print("Attempting to update Firebase display name from Apple credential to: \(appleName)")
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = appleName
            changeRequest.commitChanges { error in
                if let error = error {
                    print("Error updating Firebase profile display name: \(error.localizedDescription)")
                } else {
                    print("Successfully updated Firebase display name from Apple Sign In/Link.")
                }
            }
        } else if !appleName.isEmpty && user.displayName == appleName {
             print("Firebase display name already matches Apple credential. No update needed.")
        }
    }

    // We will implement the delegate methods in the extension below next

    // MARK: - User State Management

    /// Reloads the current user's data from Firebase to get the latest profile info, including email verification status.
    func reloadUser() {
        guard let currentUser = Auth.auth().currentUser else {
             print("AuthViewModel: reloadUser called but no current user found.")
             return
        }
        print("AuthViewModel: Reloading user data...")
        currentUser.reload { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    print("AuthViewModel: Error reloading user: \(error.localizedDescription)")
                    // Optionally set an error message, though it might be noisy if it happens frequently
                    // self.errorMessage = "Failed to update account status. Please try again later."
                } else {
                    print("AuthViewModel: User reloaded successfully. isEmailVerified: \(currentUser.isEmailVerified)")
                    // The authStateHandler should pick up the change, but we can explicitly update here
                    // to ensure the UI reacts if the listener notification is delayed.
                    let updatedIsVerified = currentUser.isEmailVerified
                    if self.isEmailVerified != updatedIsVerified {
                         self.isEmailVerified = updatedIsVerified
                         print("AuthViewModel: isEmailVerified state updated to \(updatedIsVerified) after reload.")
                         // If the user just got verified, we might need to re-trigger the status check
                         // or other actions depending on the app flow after verification.
                         // For now, GlanceApp logic will handle the view change based on the updated isEmailVerified.
                    }
                    // --- Refresh cached status after successful reload ---
                    print("AuthViewModel: Triggering checkUserStatus after successful user reload.")
                    self.checkUserStatus()
                }
            }
        }
    }

    // MARK: - Authentication Methods

    // --- Resend Verification Email ---
    func resendVerificationEmail() {
        guard let currentUser = Auth.auth().currentUser else {
            self.errorMessage = "Could not resend email. Not logged in."
            return
        }

        guard !currentUser.isEmailVerified else {
            print("User email is already verified.")
            // Optionally set a message, but likely not needed as UI should hide the button
            return
        }

        isLoading = true
        errorMessage = nil
        print("Attempting to resend verification email to: \(currentUser.email ?? "N/A")")

        // Consider Auth.auth().useAppLanguage() if localization is needed later

        currentUser.sendEmailVerification { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Failed to resend verification email: \(self.mapFirebaseError(error))"
                    print("Error resending verification email: \(error.localizedDescription)")
                } else {
                    self.errorMessage = "Verification email sent successfully. Please check your inbox (and spam folder)." // Use errorMessage for feedback
                    print("Verification email resent successfully.")
                }
            }
        }
    }

    // MARK: - Delete Account Flow

    /// Initiates the account deletion process.
    /// Checks the provider and triggers the appropriate re-authentication flow.
    func initiateDeleteAccountFlow() {
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "Cannot delete account: Not signed in."
            return
        }

        errorMessage = nil
        reauthError = nil
        needsReauthenticationForDelete = false

        // Determine the sign-in provider
        let providerId = currentUser.providerData.first?.providerID ?? ""
        print("Initiating delete account flow for provider: \(providerId)")

        if providerId == "apple.com" {
            // Start Apple re-authentication flow
            startAppleReauthForDelete()
        } else if providerId == "password" || providerId == "google.com" {
            // Require password re-authentication for email/password or Google users
            // (Google users might not have a password set up if only ever used Google Sign In,
            // but Firebase requires re-auth with *some* credential. Password is the most common.)
            // We will prompt for password in the UI.
            needsReauthenticationForDelete = true
            print("Needs password re-authentication for deletion.")
        } else {
            // Handle unexpected provider (or link multiple providers later)
            errorMessage = "Account deletion not supported for this sign-in method yet."
            print("Unsupported provider for deletion: \(providerId)")
        }
    }

    /// Starts the Apple Sign In flow specifically for re-authentication before deletion.
    @available(iOS 13.0, *)
    private func startAppleReauthForDelete() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let _ = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            handleSignInError(message: "Could not find root view controller to present Apple Sign-In for deletion.")
            return
        }

        isLoading = true
        errorMessage = nil
        isDeletingWithApple = true // Set the flag for the delegate
        print("Starting Apple Sign In flow for DELETION...")

        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        // We don't need scope here, just re-auth
        // request.requestedScopes = []
        request.nonce = sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    /// Re-authenticates the user with a password credential and then deletes the account.
    /// Call this from the UI after collecting the password.
    func reauthenticateAndDeleteWithPassword(_ password: String) {
        guard let currentUser = Auth.auth().currentUser, let email = currentUser.email else {
            reauthError = "Could not re-authenticate: User or email not found."
            return
        }

        isLoading = true
        reauthError = nil // Clear previous reauth error
        errorMessage = nil
        print("Attempting to re-authenticate user \(email) with password for deletion...")

        let credential = EmailAuthProvider.credential(withEmail: email, password: password)

        currentUser.reauthenticate(with: credential) { [weak self] authResult, error in
            // Still on main thread
            guard let self = self else { return }

            if let error = error {
                print("Re-authentication failed: \(error.localizedDescription)")
                self.reauthError = "Re-authentication failed: \(self.mapFirebaseError(error))"
                self.isLoading = false
                return
            }

            // Re-authentication successful, proceed with deletion
            print("Re-authentication successful. Deleting account...")
            self.deleteCurrentUserAccount() // Call helper to perform actual deletion
        }
    }

    /// Performs the actual user account deletion after successful re-authentication.
    private func deleteCurrentUserAccount() {
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "Could not delete account: User not found after re-authentication."
            isLoading = false
            return
        }

        // Ensure loading state is true before deletion
        isLoading = true

        currentUser.delete { [weak self] error in
            DispatchQueue.main.async { // Ensure UI updates are on main thread
                guard let self = self else { return }
                self.isLoading = false
                // Reset flags regardless of outcome
                self.needsReauthenticationForDelete = false
                self.isDeletingWithApple = false
                self.reauthError = nil

                if let error = error {
                    print("Account deletion failed: \(error.localizedDescription)")
                    self.errorMessage = "Failed to delete account: \(self.mapFirebaseError(error))"
                } else {
                    print("Account deleted successfully.")
                    self.errorMessage = nil // Clear any previous errors
                    // The authStateHandler should automatically handle the sign-out state change
                }
            }
        }
    }

}

// MARK: - ASAuthorizationControllerDelegate & ContextProviding

extension AuthViewModel: ASAuthorizationControllerDelegate {

    @available(iOS 13.0, *)
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("Apple Sign In authorization successful.")
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("Error: Could not cast authorization credential to ASAuthorizationAppleIDCredential.")
            // If deleting, use general errorMessage
            handleSignInError(message: "Apple Sign In completed but credential format was unexpected.")
            if isDeletingWithApple { isDeletingWithApple = false; isLoading = false } // Reset state
            return
        }

        guard let nonce = currentNonce else {
            fatalError("Invalid state: A login callback was received, but no login request was sent (nonce missing).")
        }
        currentNonce = nil

        guard let appleIDToken = appleIDCredential.identityToken else {
            print("Error: Unable to fetch identity token from Apple credential.")
            handleSignInError(message: "Could not get identity token from Apple.")
            if isDeletingWithApple { isDeletingWithApple = false; isLoading = false } // Reset state
            return
        }

        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("Error: Unable to serialize identity token string from data.")
            handleSignInError(message: "Could not process identity token from Apple.")
            if isDeletingWithApple { isDeletingWithApple = false; isLoading = false } // Reset state
            return
        }

        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                        rawNonce: nonce,
                                                        fullName: appleIDCredential.fullName)

        // --- Check if this completion is for DELETION or standard SIGN IN/LINK ---
        if isDeletingWithApple {
            print("Apple authorization completed in DELETION context.")
            // --- Handle Apple Re-authentication & Deletion ---
            guard let appleAuthCode = appleIDCredential.authorizationCode,
                  let authCodeString = String(data: appleAuthCode, encoding: .utf8) else {
                print("Error: Unable to fetch authorization code from Apple credential for deletion.")
                errorMessage = "Could not verify Apple session for deletion."
                isDeletingWithApple = false
                isLoading = false
                return
            }

            // Perform token revocation and deletion in a background Task
            Task {
                do {
                    print("Revoking Apple token...")
                    try await Auth.auth().revokeToken(withAuthorizationCode: authCodeString)
                    print("Apple token revoked successfully. Deleting account...")
                    // Now delete the user
                    await MainActor.run { // Ensure UI updates happen on main thread
                         self.deleteCurrentUserAccount() // Call the shared delete helper
                    }
                } catch {
                    print("Error revoking Apple token or deleting account: \(error.localizedDescription)")
                    await MainActor.run { // Ensure UI updates happen on main thread
                         self.errorMessage = "Failed to complete account deletion after Apple verification: \(self.mapFirebaseError(error))"
                         self.isDeletingWithApple = false
                         self.isLoading = false
                    }
                }
            }

        } else {
            // --- Handle Standard Sign In / Link --- (Existing Logic)
            if let currentUser = Auth.auth().currentUser {
                // --- User is already signed in - Link the new credential ---
                print("User already signed in (\(currentUser.uid)). Attempting to link Apple credential...")
                self.isLoading = true
                self.errorMessage = nil
                currentUser.link(with: credential) { [weak self] authResult, error in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                         self.isLoading = false
                         if let error = error {
                             self.handleLinkingError(error, providerName: "Apple")
                         } else {
                             // Linking successful
                             self.errorMessage = nil
                             print("Successfully linked Apple account to existing user \(authResult?.user.uid ?? "N/A").")
                             self.updateNameFromAppleCredential(appleIDCredential, user: authResult?.user)
                         }
                    }
                }
            } else {
                // --- User is not signed in - Perform sign in ---
                print("Attempting Firebase sign in with Apple credential...")
                Auth.auth().signIn(with: credential) { [weak self] (authResult, error) in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        self.isLoading = false
                        if let error = error {
                            self.errorMessage = self.mapFirebaseError(error)
                            print("Firebase Sign in with Apple credential failed: \(error.localizedDescription)")
                        } else {
                            self.errorMessage = nil
                            let userId = authResult?.user.uid ?? "N/A"
                            print("Firebase Sign in with Apple successful.")
                            print("   -> Firebase User UID: \(userId)")
                            self.updateNameFromAppleCredential(appleIDCredential, user: authResult?.user)
                            // The authStateHandler will update isAuthenticated
                        }
                    }
                }
            }
        }
    }

    @available(iOS 13.0, *)
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // --- Check if this error occurred during DELETION context ---
        let wasDeleting = isDeletingWithApple
        if wasDeleting { isDeletingWithApple = false } // Reset flag immediately

        // Handle errors from the ASAuthorizationController flow itself (e.g., user cancellation)
        let finalErrorMessage: String
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            finalErrorMessage = "Apple Sign In was cancelled."
            print(finalErrorMessage)
            DispatchQueue.main.async {
                 self.isLoading = false // Stop loading on cancellation
                 // Don't show cancellation as a persistent error unless deleting
                 if !wasDeleting {
                     self.errorMessage = nil
                 } else {
                     self.errorMessage = "Account deletion cancelled."
                 }
            }
        } else {
            // Handle other errors
            finalErrorMessage = "Apple Sign In failed: \(error.localizedDescription)"
            print(finalErrorMessage)
            // Use helper to set state, adapting message if deleting
            DispatchQueue.main.async {
                 self.errorMessage = wasDeleting ? "Apple verification failed for deletion: \(error.localizedDescription)" : finalErrorMessage
                 self.isLoading = false
            }
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
