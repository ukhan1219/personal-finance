import SwiftUI

struct LinkButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Inter-SemiBold", size: 12))
                .foregroundColor(.accent)
                .kerning(-0.01 * 12)
        }
    }
}

#Preview {
    VStack {
        LinkButton(title: "Forgot Password ?", action: {})
        LinkButton(title: "Sign Up", action: {})
    }
    .padding()
    .background(Color.appBackground)
} 