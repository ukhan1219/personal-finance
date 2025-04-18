// ios/Glance/Glance/Features/Authentication/SignupView.swift
import SwiftUI

struct SignupView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = "" // Add confirm password state
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode // To dismiss the view

    var body: some View {
        ZStack {
            // Background Color
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                 // --- Spacer at the top (less weight) ---
                 Spacer()

                // --- Header ---
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sign Up")
                        .font(.custom("Onest-Bold", size: 32))
                        .foregroundStyle(GradientConstants.titleGradient)
                        .kerning(-0.02 * 32)

                    Text("Create your account to get started")
                        .font(.custom("Inter-Medium", size: 12))
                        .foregroundColor(.secondaryText)
                        .kerning(-0.01 * 12)
                }
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)

                // --- Input Fields ---
                VStack(spacing: 16) {
                    StyledTextField(placeholder: "Email",
                                    text: $email,
                                    keyboardType: .emailAddress,
                                    autocapitalization: .none)
                    StyledTextField(placeholder: "Password",
                                    text: $password,
                                    isSecure: true)
                    StyledTextField(placeholder: "Confirm Password",
                                    text: $confirmPassword,
                                    isSecure: true)
                }
                .padding(.bottom, 24)

                // --- Sign Up Button ---
                PrimaryButton(title: "Sign Up") {
                    // Basic Validation
                    guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
                        authViewModel.errorMessage = "Please fill in all fields."
                        return
                    }
                    guard password == confirmPassword else {
                        authViewModel.errorMessage = "Passwords do not match."
                        return
                    }

                    print("Sign Up tapped - Email: \(email)")
                    authViewModel.signUp(email: email, pass: password)
                }
                .disabled(authViewModel.isLoading)
                .padding(.bottom, 16)

                // --- Display Error Messages ---
                 if let error = authViewModel.errorMessage {
                     Text(error)
                         .foregroundColor(.red)
                         .font(.caption)
                         .padding(.bottom, 8)
                         .multilineTextAlignment(.center)
                         .fixedSize(horizontal: false, vertical: true)
                 }

                 // --- Spacers at the bottom (more weight) ---
                 // Adding two Spacers here makes the bottom space larger than the top,
                 // pushing the content slightly higher for better visual centering.
                 Spacer()
                 Spacer()

                 // (Commented out login link remains outside the centered block if added back)
            }
            .padding(.horizontal, 32)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar { // The toolbar exists visually outside the VStack's layout bounds
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .foregroundStyle(GradientConstants.titleGradient)
                        .font(.title3.weight(.medium))
                }
            }
        }
         .onAppear {
             authViewModel.errorMessage = nil
         }
    }
}

#Preview {
    NavigationView {
        SignupView()
            .environmentObject(AuthViewModel())
    }
}
