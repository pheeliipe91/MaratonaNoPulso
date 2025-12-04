import SwiftUI

// MARK: - Design System Colors
extension Color {
    // Fundo Principal (Deep Charcoal - Baseado nos prints)
    static let appBackground = Color(hex: "0B0B0C")
    
    // Fundo Secundário (Cartões)
    static let cardSurface = Color(hex: "1C1C1E")
    
    // Acentos (Neon Vibrante)
    static let neonGreen = Color(hex: "CEFF00") // Verde "Marca Texto" ácido
    static let electricBlue = Color(hex: "00F0FF")
    
    // Textos
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8E8E93")
    
    // Inicializador Hex para facilitar
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
            (a, r, g, b) = (1, 1, 1, 0)
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

// MARK: - ShapeStyle Extensions for Custom Colors
extension ShapeStyle where Self == Color {
    static var neonGreen: Color { Color.neonGreen }
    static var electricBlue: Color { Color.electricBlue }
    static var appBackground: Color { Color.appBackground }
    static var cardSurface: Color { Color.cardSurface }
    static var textPrimary: Color { Color.textPrimary }
    static var textSecondary: Color { Color.textSecondary }
}

// MARK: - Estilos Visuais (Glassmorphism & Cards)
struct GlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial) // O segredo do desfoque nativo da Apple
            .background(Color.white.opacity(0.05)) // Leve tintura branca
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5) // Borda sutil
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func glass(cornerRadius: CGFloat = 20) -> some View {
        self.modifier(GlassModifier(cornerRadius: cornerRadius))
    }
    
    func appFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> some View {
        self.font(.system(style, design: .rounded).weight(weight))
    }
}
