import SwiftUI

extension Color {
    // MARK: - Brand
    static let dsBlue = Color(hex: "#2563EB")       // Blue 600 (Primary)

    // MARK: - Heatmap
    static let heatmap0 = Color.clear               // 0% (테두리만)
    static let heatmap1 = Color(hex: "#BFDBFE")     // 1~49% (Blue 200)
    static let heatmap2 = Color(hex: "#60A5FA")     // 50~99% (Blue 400)
    static let heatmap3 = Color(hex: "#2563EB")     // 100% (Blue 600)

    // MARK: - Text
    static let textPrimary = Color(hex: "#111827")
    static let textSecondary = Color(hex: "#6B7280")

    // MARK: - Surface
    static let separator = Color(hex: "#E5E7EB")
    static let surfaceSecondary = Color(hex: "#F9FAFB")
}

// MARK: - Hex Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
