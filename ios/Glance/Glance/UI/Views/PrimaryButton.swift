import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    @State private var gradientAngle: Angle = .zero

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Inter-Medium", size: 14))
                .kerning(-0.01 * 14)
                .foregroundColor(.primaryText) // Use primary text color (e.g., white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .frame(height: 44)
        }
        .background(GradientConstants.primaryButtonBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(GradientConstants.animatedAngularStroke(angle: gradientAngle), lineWidth: 2)
        )
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                gradientAngle = .degrees(360)
            }
        }
    }
}

#Preview {
    PrimaryButton(title: "Sign In", action: {})
        .padding()
        .background(Color.appBackground)
}
