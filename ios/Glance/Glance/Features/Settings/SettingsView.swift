import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    // State for password re-authentication alert - REMOVED
    // @State private var showingPasswordReauthAlert = false
    // @State private var passwordForReauth = ""

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                // --- Title --- (Adjust styling as needed)
                Text("Settings")
                    .font(.custom("Onest-Bold", size: 32))
                    .foregroundStyle(GradientConstants.titleGradient)
                    .kerning(-0.02 * 32)
                    .padding(.top, 20) // Adjust top padding
                    .padding(.bottom, 24)

                // --- User Email --- (Adjust styling as needed)
                if let email = authViewModel.user?.email {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title)
                            .foregroundColor(.secondaryText)
                        Text(email)
                            .font(.custom("Inter-Medium", size: 14))
                            .foregroundColor(.secondaryText)
                            .kerning(-0.01 * 14)
                    }
                    .padding(.bottom, 32)
                }

                // --- Settings Rows --- (Using List for separators/grouping)
                List {
                    // --- Conditionally show Reset Password --- 
                    if authViewModel.primaryProviderId == "password" {
                        SettingsRow(iconName: "key.fill", title: "Reset Password") {
                            print("Reset Password Tapped")
                            if let email = authViewModel.user?.email {
                                authViewModel.sendPasswordReset(email: email)
                            } else {
                                // Handle case where email is unexpectedly nil
                                authViewModel.errorMessage = "Could not reset password: User email not found."
                            }
                        }
                        .listRowBackground(Color.appBackground) // Ensure row matches background
                        .listRowSeparatorTint(.gray.opacity(0.3)) // Customize separator
                    }

                    SettingsRow(iconName: "rectangle.portrait.and.arrow.right", title: "Sign Out") {
                        print("Sign Out Tapped")
                        authViewModel.signOut()
                    }
                    .listRowBackground(Color.appBackground)
                    .listRowSeparatorTint(.gray.opacity(0.3))

                    SettingsRow(iconName: "trash.fill", title: "Delete Account", tintColor: .red) {
                        print("Delete Account Tapped - Initiating flow")
                        // Initiate the deletion flow in the ViewModel
                        authViewModel.initiateDeleteAccountFlow()
                        // The ViewModel will set needsReauthenticationForDelete if password is required
                        // ^-- ViewModel now handles biometric prompt internally
                    }
                    .listRowBackground(Color.appBackground)
                    .listRowSeparator(.hidden) // Hide separator after the last item
                }
                .listStyle(.plain) // Use plain style to remove default List background/inset
                .background(Color.appBackground) // Match background
                .environment(\.defaultMinListRowHeight, 50) // Adjust row height if needed
                .padding(.horizontal, -16) // Counteract default List padding if necessary
                .frame(maxHeight: 200) // Constrain list height to prevent taking full space

                // --- Error Message Display --- (Optional, can use alerts too)
                if let error = authViewModel.errorMessage {
                     Text(error)
                         .foregroundColor(.red)
                         .font(.caption)
                         .frame(maxWidth: .infinity, alignment: .center)
                         .padding(.top)
                         .multilineTextAlignment(.center)
                 }
                Spacer()
                Spacer() // Push content to top
            }
            .padding(.horizontal, 32) // Main horizontal padding for the VStack content
        }
        // --- Loading Overlay --- (Covers the whole screen when isLoading)
        /*
        .overlay {
            if authViewModel.isLoading {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
        }
        */
        .alert("Password Reset Sent", isPresented: $authViewModel.passwordResetSent, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text("If an account exists for \(authViewModel.user?.email ?? "your email"), you will receive instructions to reset your password.")
        })
        // --- REMOVED: Re-authentication Alert for Password Users ---
        /*
        .alert("Re-authenticate to Delete", isPresented: $showingPasswordReauthAlert, actions: {
            SecureField("Password", text: $passwordForReauth)
            Button("Cancel", role: .cancel) {
                 passwordForReauth = ""
                 authViewModel.reauthError = nil // Clear specific error on cancel
            }
            Button("Delete Account", role: .destructive) {
                authViewModel.reauthenticateAndDeleteWithPassword(passwordForReauth)
                passwordForReauth = "" // Clear password after attempt
            }
        }, message: {
            VStack {
                 Text("Please enter your password to confirm account deletion.")
                 // Show re-authentication error if present
                 if let reauthError = authViewModel.reauthError {
                     Text(reauthError)
                         .foregroundColor(.red)
                         .font(.caption)
                         .padding(.top, 4)
                 }
            }
        })
        */
        .onAppear {
            authViewModel.errorMessage = nil // Clear general errors when view appears
            // authViewModel.reauthError = nil // Clear re-auth errors - REMOVED
        }
        // --- REMOVED onChange modifiers for re-auth alert ---
        /*
        // --- Updated onChange for iOS 17+ ---
        .onChange(of: authViewModel.needsReauthenticationForDelete) {
            // Show the alert when the ViewModel indicates it's needed
            if authViewModel.needsReauthenticationForDelete {
                passwordForReauth = "" // Clear password field before showing
                showingPasswordReauthAlert = true
                authViewModel.needsReauthenticationForDelete = false // Reset the trigger
            }
        }
        // Also trigger alert presentation if a reauthError occurs AFTER the flag was set
        // This covers cases where the first password attempt failed.
        // --- Updated onChange for iOS 17+ ---
        .onChange(of: authViewModel.reauthError) { 
            if authViewModel.reauthError != nil && !showingPasswordReauthAlert {
                 showingPasswordReauthAlert = true
            }
        }
        */
    }
}

#Preview {
    let mockAuthViewModel = AuthViewModel()
    // mockAuthViewModel.user = ... // Set mock user if needed for preview
    // mockAuthViewModel.errorMessage = "Sample error message"
    // mockAuthViewModel.isLoading = true
    // mockAuthViewModel.needsReauthenticationForDelete = true // Test alert trigger
    // mockAuthViewModel.reauthError = "Incorrect password"

    return TabView { // Preview in TabView context
         Text("Spending View Placeholder").tag(0)
         SettingsView()
             .environmentObject(mockAuthViewModel)
             .tag(1)
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .background(Color.appBackground.ignoresSafeArea())
} 