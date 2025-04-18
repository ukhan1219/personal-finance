import SwiftUI

struct PlaidConnectView: View {
    // EnvironmentObject to potentially access PlaidViewModel later
    // @EnvironmentObject var plaidViewModel: PlaidViewModel
    @EnvironmentObject var authViewModel: AuthViewModel // Needed to potentially trigger Plaid flow

    var body: some View {
        ZStack {
            // Background Color
            Color.appBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer() // Pushes content towards center initially

                // Header Text
                VStack(alignment: .leading, spacing: 12) {
                    Text("Connect your bank account")
                        .font(.custom("Onest-Bold", size: 32)) // Use Onest-Bold
                        .foregroundStyle(GradientConstants.titleGradient) // Use existing gradient
                        .kerning(-0.02 * 32) // Apply kerning

                    Text("Connect your bank account to see your spending trends and insights.")
                        .font(.custom("Inter-Medium", size: 12)) // Use Inter-Medium
                        .foregroundColor(.secondaryText) // Use secondary text color
                        .kerning(-0.01 * 12) // Apply kerning
                }
                .padding(.bottom, 32) // Spacing below header

                // Connect Button
                PrimaryButton(title: "Connect bank account") {
                    connectBankAccountAction()
                }
                .padding(.bottom, 16) // Spacing below button (adjust if needed)

                // Optional: Maybe Later Button (if desired, uncomment and style)
                /*
                Button("Maybe Later") {
                    // Handle maybe later action (e.g., dismiss, go to limited dashboard)
                    print("Maybe Later tapped")
                }
                .font(.custom("Inter-SemiBold", size: 12))
                .foregroundColor(Color.accentColor) // Or your specific link color
                .frame(maxWidth: .infinity, alignment: .center)
                */

                Spacer() // Pushes content towards center
                Spacer() // Add more weight to bottom spacer
            }
            .padding(.horizontal, 24) // Apply horizontal padding to the VStack content
        }
        // Add navigation title if this view is embedded in a NavigationStack later
        // .navigationTitle("Connect Bank")
        // .navigationBarTitleDisplayMode(.inline)
    }

    func connectBankAccountAction() {
        // TODO: Implement Plaid Link Trigger
        // This will eventually call something like:
        // plaidViewModel.fetchLinkTokenAndOpenPlaid()
        print("Connect bank account button tapped!")
        // For now, let's simulate connection success by updating the flag
        // In reality, this flag would be updated *after* successful Plaid connection & token exchange
        authViewModel.needsPlaidConnection = false
        print("Simulating successful connection, setting needsPlaidConnection to false")
    }
}

// MARK: - Preview
struct PlaidConnectView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock AuthViewModel for the preview
        let mockAuthViewModel = AuthViewModel()
        // mockAuthViewModel.isAuthenticated = true // Ensure user is authenticated for this view state
        // mockAuthViewModel.needsPlaidConnection = true // Ensure connection is needed

        // Embed in NavigationStack if needed for title/bar items
        // NavigationStack {
            PlaidConnectView()
                .environmentObject(mockAuthViewModel)
        // }
    }
}
