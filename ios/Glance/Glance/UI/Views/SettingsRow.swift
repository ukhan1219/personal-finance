import SwiftUI

// Reusable row component for Settings screen items
struct SettingsRow: View {
    let iconName: String
    let title: String
    let tintColor: Color // Allow customizing tint for icons/text (e.g., red for delete)
    let action: () -> Void

    init(iconName: String, title: String, tintColor: Color = .primaryText, action: @escaping () -> Void) {
        self.iconName = iconName
        self.title = title
        self.tintColor = tintColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: iconName)
                    .font(.body.weight(.medium)) // Adjust font/weight as needed
                    .foregroundColor(tintColor)
                    .frame(width: 24, alignment: .center) // Consistent icon width

                // Title
                Text(title)
                    .font(.custom("Inter-Medium", size: 16))
                    .foregroundColor(tintColor)
                    .kerning(-0.01 * 16)

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.secondaryText.opacity(0.6)) // Subtle chevron color
            }
            .padding(.vertical, 12) // Vertical padding for the row
            .contentShape(Rectangle()) // Ensure the whole row is tappable
        }
        .buttonStyle(.plain) // Use plain button style to avoid default button appearance interference
    }
}

#Preview {
    List { // Preview within a List context for realistic spacing
        SettingsRow(iconName: "key.fill", title: "Reset Password") {}
        SettingsRow(iconName: "rectangle.portrait.and.arrow.right", title: "Sign Out") {}
        SettingsRow(iconName: "trash.fill", title: "Delete Account", tintColor: .red) {}
    }
    .listStyle(.plain) // Use plain list style for preview
    .padding()
    .background(Color.appBackground) // Use app background for context
} 