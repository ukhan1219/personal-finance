import Foundation
import Combine
import FirebaseAuth // For Firebase Auth
import FirebaseCore // Often needed alongside FirebaseAuth
import GoogleSignIn // For Google Sign-In logic
import UIKit // Needed for getting the root view controller

class AuthViewModel: ObservableObject {
    @Published var user: User? // Firebase User object
    @Published var isAuthenticated: Bool = false
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false // To show loading indicators

    private var authStateHandler: AuthStateDidChangeListenerHandle?

    init() {
        registerAuthStateHandler()
    }

    deinit {
        if let handle = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // Keep the existing auth state listener from the overview.md example
    func registerAuthStateHandler() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            guard let self = self else { return }
            self.user = user
            self.isAuthenticated = (user != nil)
            self.isLoading = false // Stop loading when auth state changes
            print("Auth State Changed: User \(user?.uid ?? "nil")")
        }
    }

    // --- Email/Password Sign Up ---
    func signUp(email: String, pass: String) {
        isLoading = true
        errorMessage = nil

        Auth.auth().createUser(withEmail: email, password: pass) { [weak self] (result, error) in
            guard let self = self else { return }
            // Ensure isLoading is set back to false regardless of outcome
             DispatchQueue.main.async {
                 self.isLoading = false
                 if let error = error {
                     self.errorMessage = "Sign Up failed: \(error.localizedDescription)"
                     print("Sign up error: \(error.localizedDescription)")
                 } else {
                     self.errorMessage = nil // Clear error on success
                     print("Sign up successful: \(result?.user.uid ?? "N/A")")
                     // Auth state listener will automatically update isAuthenticated and user
                 }
             }
        }
    }

    // --- Email/Password Sign In ---
    func signIn(email: String, pass: String) {
        isLoading = true
        errorMessage = nil

        Auth.auth().signIn(withEmail: email, password: pass) { [weak self] (result, error) in
             guard let self = self else { return }
             // Ensure isLoading is set back to false regardless of outcome
              DispatchQueue.main.async {
                  self.isLoading = false
                  if let error = error {
                      self.errorMessage = "Sign In failed: \(error.localizedDescription)"
                      print("Sign in error: \(error.localizedDescription)")
                  } else {
                      self.errorMessage = nil // Clear error on success
                      print("Sign in successful: \(result?.user.uid ?? "N/A")")
                      // Auth state listener will automatically update isAuthenticated and user
                  }
              }
        }
    }

    // --- Google Sign-In Logic ---
    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil

        // 1. Get Client ID from Firebase options
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Google Sign-In client ID not found in Firebase options."
            isLoading = false
            return
        }

        // 2. Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // 3. Get root view controller to present Google Sign-In flow
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            errorMessage = "Could not find root view controller to present Google Sign-In."
            isLoading = false
            print("Could not get root view controller.")
            return
        }

        // 4. Start the sign in flow!
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
                self.isLoading = false
                print("Google Sign-In error: \(error.localizedDescription)")
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                self.errorMessage = "Google Sign-In succeeded but failed to get ID token."
                self.isLoading = false
                print("Google Sign-In missing ID token.")
                return
            }

            // 5. Create Firebase credential
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                             accessToken: user.accessToken.tokenString)

            // 6. Sign in to Firebase Auth
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    self.errorMessage = "Firebase Sign-In with Google credential failed: \(error.localizedDescription)"
                    self.isLoading = false
                    print("Firebase Sign-In error: \(error.localizedDescription)")
                    return
                }

                // Auth state listener will automatically update isAuthenticated and user
                // isLoading will also be set to false by the listener
                print("Successfully signed in with Firebase using Google credential for user: \(authResult?.user.uid ?? "N/A")")
                self.errorMessage = nil
                // No need to set isLoading = false here, listener handles it.
            }
        }
    }

    // Add other methods like signOut, email/password sign-in/signup later
    func signOut() {
         do {
             // Sign out from Google as well if needed
             GIDSignIn.sharedInstance.signOut()
             try Auth.auth().signOut()
             print("Sign out successful")
             // Auth state listener will update state
         } catch let signOutError as NSError {
             self.errorMessage = "Error signing out: \(signOutError.localizedDescription)"
             print("Error signing out: %@", signOutError)
             self.isLoading = false // Ensure loading stops on error
         }
     }
}
