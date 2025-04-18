import SwiftUI
// No need to import GoogleSignIn here unless using GIDSignInButton directly

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    // Add EnvironmentObject for AuthViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    // Add state for navigation to SignupView
    @State private var navigateToSignup = false

    var body: some View {
        // Use NavigationStack instead of NavigationView
        NavigationStack {
            ZStack {
                // Background Color
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Add Spacer at the top for centering
                    Spacer()

                    // Header Text
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sign In")
                            .font(.custom("Onest-Bold", size: 32))
                            .foregroundStyle(GradientConstants.titleGradient)
                            .kerning(-0.02 * 32)

                        Text("Enter your email and password to sign in")
                            .font(.custom("Inter-Medium", size: 12))
                            .foregroundColor(.secondaryText)
                            .kerning(-0.01 * 12)
                    }
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Input Fields
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            StyledTextField(placeholder: "Email",
                                            text: $email,
                                            keyboardType: .emailAddress,
                                            autocapitalization: .none)
                            StyledTextField(placeholder: "Password",
                                            text: $password,
                                            isSecure: true)
                        }

                        // Forgot Password Link
                        HStack {
                            Spacer()
                            LinkButton(title: "Forgot Password ?") {
                                // TODO: Implement forgot password action
                                print("Forgot Password tapped")
                            }
                            Spacer()
                        }
                    }
                    .padding(.bottom, 24)

                    // Buttons
                    VStack(spacing: 16) {
                        PrimaryButton(title: "Sign In") {
                            print("Sign In tapped - Email: \(email), Pass: \(password)")
                            authViewModel.signIn(email: email, pass: password)
                        }

                        OrDivider()
                        socialLoginButtons
                    }

                    // Spacer to push the "Sign Up" link to the bottom
                    Spacer()
                    Spacer()

                    // Sign Up Link (This remains at the bottom)
                    HStack(spacing: 6) {
                        Text("Don't have an account?")
                            .font(.custom("Inter-Medium", size: 12))
                            .foregroundColor(.secondaryText)
                            .kerning(-0.01 * 12)

                        Button("Sign Up") {
                            navigateToSignup = true
                        }
                        .font(.custom("Inter-SemiBold", size: 12))
                        .foregroundColor(.accent)
                        .kerning(-0.01 * 12)
                    }
                    .padding(.bottom, 16) // Bottom padding from Figma
                }
                .padding(.horizontal, 32)
                 // Add the navigationDestination modifier here
                 .navigationDestination(isPresented: $navigateToSignup) {
                     SignupView() // Destination view
                 }
            }
        } // End NavigationStack
        .onAppear {
            authViewModel.errorMessage = nil
        }
    }

    // MARK: - Subviews
    private var socialLoginButtons: some View {
        // Wrap everything in a parent VStack
        VStack(spacing: 8) {
            // The VStack containing the actual buttons
            VStack(spacing: 8) {
                SocialButton(iconName: "google-logo", text: "Continue with Google") {
                    print("Google Sign In tapped - initiating flow")
                    authViewModel.signInWithGoogle()
                }
                SocialButton(iconName: "apple-logo", text: "Continue with Apple") {
                    // Call the startSignInWithAppleFlow method from the ViewModel
                    print("Apple Sign In tapped - initiating flow")
                    authViewModel.startSignInWithAppleFlow()
                }
            }

            // Display error messages from the ViewModel within the parent VStack
            if let error = authViewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, 8)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } // End of parent VStack
    }
}

#Preview {
    // Preview uses NavigationStack as well
    NavigationStack {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
