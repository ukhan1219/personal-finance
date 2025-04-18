import SwiftUI

// Helper extension for Hex color initialization
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0) // Invalid format, default to clear
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // MARK: - App Palette
    static let appBackground = Color(hex: "#0C0C0C")
    static let appForeground = Color(hex: "#F5F5F5") // General light foreground/component background
    static let primaryText = Color(hex: "#F5F5F5") // Or slightly off-white like #F5F5F5
    static let secondaryText = Color(hex: "#6C7278")
    static let accent = Color(hex: "#C175F5") // Used for links/highlights

    static let textFieldBackground = Color(hex: "#F5F5F5")
    static let textFieldStroke = Color(hex: "#EDF1F3")
    static let textFieldPlaceholder = Color(hex: "#1A1C1E").opacity(0.5)
    static let textFieldText = Color(hex: "#0C0C0C") // Text inside text fields

    static let dividerLine = Color(hex: "#D9DDDF")

    static let socialButtonBackground = Color(hex: "#F5F5F5")
    static let socialButtonStroke = Color(hex: "#EFF0F6")
    static let socialButtonText = Color(hex: "#0C0C0C")

    // Gradient Colors
    static let gradientStart = Color(hex: "#4983F6")
    static let gradientMid = Color(hex: "#C175F5")
    static let gradientEnd = Color(hex: "#FBACB7")
}
