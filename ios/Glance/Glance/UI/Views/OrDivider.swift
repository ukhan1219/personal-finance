import SwiftUI

struct OrDivider: View {
    var body: some View {
        HStack(spacing: 16) {
            line
            Text("Or")
                .font(.custom("Inter-Regular", size: 12))
                .foregroundColor(.secondaryText)
                .kerning(-0.01 * 12)
            line
        }
    }

    private var line: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundColor(.dividerLine)
    }
}

#Preview {
    OrDivider()
        .padding()
        .background(Color.appBackground)
} 