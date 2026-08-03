import SwiftUI

public enum Theme {
    // Colors based on Sodalite Blue and Paper & Ink theme
    public static let sodalite = Color(red: 0.17, green: 0.32, blue: 0.47) // oklch(0.55 0.16 252)
    public static let paper = Color(red: 0.98, green: 0.97, blue: 0.96)     // #faf8f4
    public static let ink = Color(red: 0.11, green: 0.10, blue: 0.09)      // #1c1917
    public static let muted = Color(red: 0.47, green: 0.44, blue: 0.42)    // #78716c
    public static let lockGreen = Color(red: 0.39, green: 0.78, blue: 0.25) // oklch(0.62 0.15 150)

    public static let cardBackground = Color.white
    public static let secondaryBackground = Color(red: 0.96, green: 0.96, blue: 0.94)
}

extension View {
    func paperTheme() -> some View {
        self.background(Theme.paper)
            .foregroundColor(Theme.ink)
    }
}
