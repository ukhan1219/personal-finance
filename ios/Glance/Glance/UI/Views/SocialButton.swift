import SwiftUI

struct SocialButton: View {
    let iconName: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) { // Figma gap is 10
                Image(iconName) // Assumes icon is in Assets
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)

                Text(text)
                    .font(.custom("Inter-SemiBold", size: 14))
                    .kerning(-0.01 * 14)
                    .foregroundColor(.socialButtonText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .frame(height: 44)
        }
        .background(Color.socialButtonBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.socialButtonStroke, lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 8) {
        SocialButton(iconName: "google-logo", text: "Continue with Google", action: {})
        SocialButton(iconName: "apple-logo", text: "Continue with Apple", action: {})
    }
    .padding()
    .background(Color.appBackground)
} 