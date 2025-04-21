import SwiftUI

struct PrimaryButton: View {
    let title: String
    let iconName: String?
    let action: () -> Void

    @State private var gradientAngle: Angle = .zero

    init(title: String, iconName: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.iconName = iconName
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let iconName = iconName {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 20)
                }
                Text(title)
                    .font(.custom("Inter-Medium", size: 14))
                    .kerning(-0.01 * 14)
            }
            .foregroundColor(.primaryText)
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
    VStack(spacing: 20) {
        PrimaryButton(title: "Sign In", action: {})
        PrimaryButton(title: "Button With Icon", iconName: "google-logo", action: {})
    }
    .padding()
    .background(Color.appBackground)
}
