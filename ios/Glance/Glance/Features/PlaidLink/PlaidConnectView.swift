import SwiftUI

struct PlaidConnectView: View {
    // Get PlaidViewModel from the environment
    @EnvironmentObject var plaidViewModel: PlaidViewModel
    @EnvironmentObject var authViewModel: AuthViewModel // Still needed?

    var body: some View {
        ZStack {
            // Background Color
            Color.appBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer() // Pushes content towards center initially

                // Header Text
                VStack(alignment: .leading, spacing: 12) {
                    Text("Connect your bank account")
                        .font(.custom("Onest-Bold", size: 32))
                        .foregroundStyle(GradientConstants.titleGradient)
                        .kerning(-0.02 * 32)

                    Text("Connect your bank account to see your spending trends and insights.")
                        .font(.custom("Inter-Medium", size: 12))
                        .foregroundColor(.secondaryText)
                        .kerning(-0.01 * 12)
                }
                .padding(.bottom, 32)

                // --- Loading Indicator --- (Shown while PlaidVM is loading)
                
                    // --- Connect Button --- (Shown when not loading)
                    PrimaryButton(title: "", iconName: "plaid-logo") {
                        connectBankAccountAction()
                    }
                    .padding(.bottom, 16)


                // --- Error Message Display --- (Shown if PlaidVM has an error)
                if let errorMessage = plaidViewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                }

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            // Clear any previous Plaid error when the view appears
            plaidViewModel.errorMessage = nil
        }
    }

    func connectBankAccountAction() {
        // Call the method on the PlaidViewModel to start the flow
        print("Connect bank account button tapped - calling PlaidViewModel.openPlaidLink()")
        plaidViewModel.openPlaidLink()
    }
}

// MARK: - Preview
struct PlaidConnectView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock AuthViewModel and APIService for PlaidViewModel dependency
        let mockAuthViewModel = AuthViewModel()
        let mockAPIService = APIService(authViewModel: mockAuthViewModel)
        // Create mock PlaidViewModel
        let mockPlaidViewModel = PlaidViewModel(apiService: mockAPIService, authViewModel: mockAuthViewModel)

        // Example states for preview:
        // mockPlaidViewModel.isLoading = true
        // mockPlaidViewModel.errorMessage = "Failed to connect. Please try again."

        PlaidConnectView()
            .environmentObject(mockAuthViewModel)
            .environmentObject(mockPlaidViewModel)
    }
}
