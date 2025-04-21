import SwiftUI
import UIKit // Needed for UIApplication

struct EmailVerificationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    // Optional state to briefly disable resend button
    @State private var recentlyResent = false

    var userEmail: String {
        // Attempt to get the email from the Firebase user
        authViewModel.user?.email ?? "your email address"
    }

    var body: some View {
        ZStack {
            // Background Color
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer() // Push content towards center

                // Header Text
                VStack(alignment: .leading, spacing: 12) {
                    Text("Verify Your Email")
                        .font(.custom("Onest-Bold", size: 32))
                        .foregroundStyle(GradientConstants.titleGradient)
                        .kerning(-0.02 * 32)

                    Text("We sent a verification link to **\\(userEmail)**. Please check your inbox (and spam folder) and click the link to activate your account.")
                        .font(.custom("Inter-Medium", size: 12))
                        .foregroundColor(.secondaryText)
                        .kerning(-0.01 * 12)
                        .lineSpacing(4) // Improve readability
                }
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Buttons
                VStack(spacing: 16) {
                    // Open Mail App Button (Uses Primary style for emphasis)
                    PrimaryButton(title: "Open Mail App") {
                        openMailApp()
                    }

                    // Resend Email Button (Uses Secondary style)
                    SecondaryButton(title: "Resend Verification Email") {
                        resendVerificationEmail()
                    }
                    .disabled(recentlyResent || authViewModel.isLoading) // Disable if loading or recently resent
                }
                .padding(.bottom, 24)

                 // --- Error Message Display ---
                 if let errorMessage = authViewModel.errorMessage {
                     // Show feedback/error messages prominently
                     Text(errorMessage)
                         .font(.custom("Inter-Medium", size: 12))
                         .foregroundColor(errorMessage.contains("successfully") ? .green : .red) // Green for success, Red for error
                         .frame(maxWidth: .infinity, alignment: .center)
                         .multilineTextAlignment(.center)
                         .padding(.horizontal)
                         .padding(.bottom, 10)
                 }


                Spacer() // Spacer before logout
                Spacer()

                // Logout Button
                Button("Logout") {
                    authViewModel.signOut()
                }
                .font(.custom("Inter-SemiBold", size: 14))
                .foregroundColor(.secondaryText) // Use a less prominent color
                .padding(.bottom, 16) // Bottom padding from Figma
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            // Clear any error message specific to other flows when this view appears
             authViewModel.errorMessage = nil
        }
        // Optional: Add navigation title or bar if needed within a NavigationStack context later
    }

    // MARK: - Actions

    func openMailApp() {
        print("Attempting to open mail app...")
        // Common URL scheme for Mail app
        guard let url = URL(string: "message://"), UIApplication.shared.canOpenURL(url) else {
            print("Cannot open mail app or URL scheme not supported.")
            // Optionally show an alert to the user
            authViewModel.errorMessage = "Could not automatically open mail app. Please check your email manually."
            return
        }
        UIApplication.shared.open(url)
    }

    func resendVerificationEmail() {
        print("Resend verification email tapped.")
        authViewModel.resendVerificationEmail()
        // Briefly disable the button to prevent spamming
        recentlyResent = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { // Re-enable after 30 seconds
            recentlyResent = false
        }
    }
}

// MARK: - Preview
#Preview {
    // Create mock AuthViewModel for preview
    let mockAuthViewModel = AuthViewModel()
    // Simulate a logged-in but unverified user
    // Note: Creating a mock Firebase User is complex, so we'll use placeholder text
    // In a real scenario, you might need a more sophisticated mocking setup.
    mockAuthViewModel.isAuthenticated = true
    mockAuthViewModel.isEmailVerified = false
    // mockAuthViewModel.errorMessage = "Verification email sent successfully." // Example message

    return EmailVerificationView()
        .environmentObject(mockAuthViewModel)
}

// Placeholder for SecondaryButton if it doesn't exist
// You should replace this with your actual SecondaryButton implementation
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Inter-SemiBold", size: 14))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16) // Standard padding
                .background(Color.gray.opacity(0.2)) // Example secondary style
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }
} 