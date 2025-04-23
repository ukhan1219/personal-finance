import SwiftUI

struct SpendingView: View {
    // Use @StateObject if the ViewModel is owned by this view,
    // or @EnvironmentObject if it's provided by a parent (like GlanceApp).
    // Since GlanceApp will own it, we use @EnvironmentObject here.
    @EnvironmentObject var viewModel: SpendingViewModel
    @EnvironmentObject var authViewModel: AuthViewModel // Needed for logout

    // Define the gray color for labels
    let labelGray = Color(red: 0.96, green: 0.96, blue: 0.96) // #f5f5f5

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(alignment: .leading) {
                // --- Spending Display ---
                if let summary = viewModel.spendingSummary {
                    // Data available state
                    VStack(alignment: .leading, spacing: 8) { // Adjust spacing as needed
                        SpendingRow(amount: summary.month, label: "m", opacity: 1.0, labelGray: labelGray)
                        SpendingRow(amount: summary.week, label: "w", opacity: 0.666, labelGray: labelGray)
                        SpendingRow(amount: summary.today, label: "d", opacity: 0.333, labelGray: labelGray)
                    }
                    .padding(.top, 40) // Add top padding
                    .padding(.leading, 24) // Add leading padding

                    Spacer() // Push content to the top

                    // --- Error/Refresh Indicator ---
                     if let error = viewModel.errorMessage {
                         Text(error)
                             .font(.custom("Manrope-Bold", size: 12)) // Use Manrope
                             .foregroundColor(.red)
                             .frame(maxWidth: .infinity, alignment: .center)
                             .padding()
                     }

                    // --- Logout Button (Temporary) ---
                    HStack {
                        Spacer()
                        Spacer()
                    }

                } else if let error = viewModel.errorMessage {
                     // Error state when no data could be loaded
                     VStack {
                        Spacer()
                        Text("Error loading spending data:")
                            .font(.custom("Manrope-Bold", size: 14)) // Use Manrope
                            .foregroundColor(.secondaryText)
                        Text(error)
                            .font(.custom("Manrope-Bold", size: 12)) // Use Manrope
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        Spacer()
                     }.padding()
                } else {
                     // Fallback for unexpected state (shouldn't normally happen)
                     // Display $0 values initially instead of "No data"
                    VStack(alignment: .leading, spacing: 8) { 
                        SpendingRow(amount: 0, label: "m", opacity: 1.0, labelGray: labelGray)
                        SpendingRow(amount: 0, label: "w", opacity: 0.666, labelGray: labelGray)
                        SpendingRow(amount: 0, label: "d", opacity: 0.333, labelGray: labelGray)
                    }
                    .padding(.top, 40)
                    .padding(.leading, 24)
                 }
            }
        }
    }
}

// MARK: - Spending Row Subview
struct SpendingRow: View {
    let amount: Double
    let label: String
    let opacity: Double
    let labelGray: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) { // Align text baselines
            Text("$")
                .font(.custom("Manrope-Bold", size: 32)) // Use Manrope
                .foregroundColor(labelGray)

            Text(amountString)
                .font(.custom("Manrope-Bold", size: 48)) // Use Manrope
                .foregroundStyle(GradientConstants.titleGradient)

            Text(label)
                .font(.custom("Manrope-Bold", size: 32)) // Use Manrope
                .foregroundColor(labelGray)
                .padding(.leading, 4) // Add small space before label
        }
        .opacity(opacity)
    }

    private var amountString: String {
        // Custom formatting to remove decimals if it's a whole number
        let number = NSNumber(value: amount)
        let formatter = CurrencyFormatter.formatter
        // Check if the number has no fractional part
        if floor(amount) == amount {
            formatter.maximumFractionDigits = 0
        } else {
            formatter.maximumFractionDigits = 2
        }
        // Remove currency symbol as we add it manually
        formatter.currencySymbol = ""
        return formatter.string(from: number) ?? "?.??"
    }
}

// MARK: - Preview
struct SpendingView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock dependencies
        let mockAuthViewModel = AuthViewModel()
        let mockAPIService = APIService(authViewModel: mockAuthViewModel)
        let mockSpendingViewModel = SpendingViewModel(apiService: mockAPIService)

        // Setup mock data for preview
        mockSpendingViewModel.spendingSummary = SpendingSummary(today: 12.34, week: 150.50, month: 875.99)
        // mockSpendingViewModel.isLoading = true
        // mockSpendingViewModel.errorMessage = "Could not connect to server."

        return SpendingView()
            .environmentObject(mockSpendingViewModel)
            .environmentObject(mockAuthViewModel)
    }
}
