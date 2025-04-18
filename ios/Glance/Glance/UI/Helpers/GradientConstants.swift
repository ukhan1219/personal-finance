import SwiftUI

struct GradientConstants {
    static let titleGradient = LinearGradient(
        gradient: Gradient(colors: [.gradientStart, .gradientMid, .gradientEnd]),
        startPoint: .leading,
        endPoint: .trailing
    )

    static let primaryButtonBackground = LinearGradient(
        gradient: Gradient(colors: [.gradientStart, .gradientMid, .gradientEnd]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Function to create the animated stroke gradient
    static func animatedAngularStroke(angle: Angle) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [.gradientEnd, .gradientMid, .gradientStart, .gradientEnd]), // Repeat first color for smooth loop
            center: .center,
            angle: angle
        )
    }
} 