import SwiftUI

struct LockedView: View {
    @EnvironmentObject var authViewModel: AuthViewModel // Get access to trigger unlock again if needed

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Icon indicating lock/biometrics - Now wrapped in a Button
                Button {
                    print("LockedView: Lock icon tapped. Requesting biometric unlock.")
                    authViewModel.requestBiometricUnlock()
                } label: {
                    Image(systemName: "lock.shield.fill") // Or "faceid", "touchid"
                        .font(.system(size: 60))
                        .foregroundStyle(GradientConstants.titleGradient)
                }
                .buttonStyle(.plain) // Use plain style to keep icon appearance

                Text("Glance is Locked")
                            .font(.custom("Onest-Bold", size: 32))
                            .foregroundStyle(GradientConstants.titleGradient)
                            .kerning(-0.02 * 32)

                Text("Unlock to Continue")
                            .font(.custom("Inter-Medium", size: 12))
                            .foregroundColor(.secondaryText)
                            .kerning(-0.01 * 12)

                // Optional: Button to manually trigger the auth prompt again
                // Useful if the initial prompt fails or is dismissed by the system
                // before the user interacts.
                /*
                Button {
                    print("LockedView: Manually requesting biometric unlock.")
                    authViewModel.requestBiometricUnlock()
                } label: {
                    Label("Unlock", systemImage: "faceid")
                        .font(.custom("Inter-SemiBold", size: 16))
                }
                .padding(.top, 10)
                .buttonStyle(.borderedProminent)
                .tint(.accent)
                */

                Spacer()
                Spacer()
            }
            .padding()
        }
        // Consider adding `.interactiveDismissDisabled()` if presented as a sheet
        // to prevent swiping down to dismiss the lock.
        // Since it's part of the main view hierarchy, this isn't strictly needed here.
    }
}

#Preview {
    LockedView()
        .environmentObject(AuthViewModel()) // Provide mock VM for preview
} 