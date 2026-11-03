import SwiftUI

enum PulseTheme {
    static let bgA = Color(red: 7 / 255, green: 7 / 255, blue: 15 / 255)
    static let bgB = Color(red: 18 / 255, green: 10 / 255, blue: 40 / 255)
    static let surface = Color(red: 20 / 255, green: 18 / 255, blue: 36 / 255).opacity(0.92)
    static let surfaceStrong = Color(red: 22 / 255, green: 19 / 255, blue: 40 / 255)
    static let textMain = Color(red: 244 / 255, green: 238 / 255, blue: 255 / 255)
    static let textMuted = Color(red: 187 / 255, green: 167 / 255, blue: 219 / 255)
    static let purple = Color(red: 180 / 255, green: 0 / 255, blue: 1)
    static let pink = Color(red: 1, green: 43 / 255, blue: 214 / 255)
    static let green = Color(red: 53 / 255, green: 1, blue: 134 / 255)
    static let red = Color(red: 1, green: 71 / 255, blue: 102 / 255)
    static let blue = Color(red: 74 / 255, green: 191 / 255, blue: 1)
    static let line = Color(red: 50 / 255, green: 43 / 255, blue: 79 / 255)
    static let chartColors: [Color] = [purple, pink, green, red, Color(red: 127 / 255, green: 92 / 255, blue: 1), Color(red: 0, green: 240 / 255, blue: 1)]

    static let displayFont = Font.system(.largeTitle, design: .serif).weight(.bold)
    static let titleFont = Font.system(.title2, design: .serif).weight(.semibold)
    static let sectionFont = Font.system(.title3, design: .serif).weight(.semibold)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 47 / 255, green: 11 / 255, blue: 86 / 255).opacity(0.85),
                bgA,
                bgB
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var primaryGradient: LinearGradient {
        LinearGradient(colors: [purple, pink], startPoint: .leading, endPoint: .trailing)
    }
}

struct PulseBackground: View {
    var body: some View {
        ZStack {
            PulseTheme.backgroundGradient
            Circle()
                .fill(PulseTheme.pink.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: 140, y: -220)
            Circle()
                .fill(PulseTheme.purple.opacity(0.2))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: -160, y: 280)
        }
        .ignoresSafeArea()
    }
}

struct PulseCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(PulseTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(PulseTheme.line.opacity(0.8), lineWidth: 1)
                    )
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var disabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(PulseTheme.textMain)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(PulseTheme.primaryGradient)
                    .opacity(disabled ? 0.45 : (configuration.isPressed ? 0.85 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(PulseTheme.textMain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 29 / 255, green: 23 / 255, blue: 54 / 255))
                    .opacity(configuration.isPressed ? 0.7 : 1)
            )
    }
}

struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(PulseTheme.textMain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PulseTheme.red.opacity(configuration.isPressed ? 0.55 : 0.85))
            )
    }
}

extension View {
    func pulseScreen() -> some View {
        self
            .foregroundStyle(PulseTheme.textMain)
            .background(PulseBackground())
    }
}

enum MoneyFormat {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func string(_ value: Double) -> String {
        currency.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }
}

enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
