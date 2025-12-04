import SwiftUI

// MARK: - Color Extensions

extension Color {
    // App color palette - Warm sunset gradient theme
    static let appBackground = Color(hex: "1a1a2e")
    static let appSurface = Color(hex: "16213e")
    static let appPrimary = Color(hex: "e94560")
    static let appSecondary = Color(hex: "0f3460")
    static let appAccent = Color(hex: "ff6b6b")
    static let appSuccess = Color(hex: "4ecdc4")
    static let appWarning = Color(hex: "ffd93d")
    static let appText = Color(hex: "eaeaea")
    static let appTextSecondary = Color(hex: "a0a0a0")
    
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

// MARK: - View Extensions

extension View {
    func glowEffect(color: Color, radius: CGFloat = 10) -> some View {
        self
            .shadow(color: color.opacity(0.6), radius: radius / 2, x: 0, y: 0)
            .shadow(color: color.opacity(0.3), radius: radius, x: 0, y: 0)
    }
    
    func cardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.appSurface)
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
            )
    }
    
    func shimmer(isActive: Bool) -> some View {
        self.modifier(ShimmerModifier(isActive: isActive))
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    if isActive {
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(0.3),
                                Color.white.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 2)
                        .offset(x: -geo.size.width + phase * geo.size.width * 2)
                        .onAppear {
                            withAnimation(
                                .linear(duration: 1.5)
                                .repeatForever(autoreverses: false)
                            ) {
                                phase = 1
                            }
                        }
                    }
                }
                .mask(content)
            )
    }
}

// MARK: - Time Formatting

extension TimeInterval {
    var formattedTimer: String {
        let total = Int(self)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Compact format for timer row - no leading zeros for hours
    var formattedTimerCompact: String {
        let total = Int(self)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedTimerWithMillis: String {
        let total = Int(self)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        let millis = Int((self.truncatingRemainder(dividingBy: 1)) * 10)
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%d", hours, minutes, seconds, millis)
        }
        return String(format: "%02d:%02d.%d", minutes, seconds, millis)
    }
}

// MARK: - Haptic Feedback

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// MARK: - Animation Extensions

extension Animation {
    static var smoothSpring: Animation {
        .spring(response: 0.4, dampingFraction: 0.8)
    }
    
    static var quickSpring: Animation {
        .spring(response: 0.3, dampingFraction: 0.7)
    }
    
    static var gentleBounce: Animation {
        .spring(response: 0.5, dampingFraction: 0.6)
    }
}

