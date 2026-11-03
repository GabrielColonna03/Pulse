import SwiftUI

// Legacy shared helpers kept for sheets that still need them.
// Primary mobile chrome lives in MobileChrome.swift.

struct MetricTile: View {
    var label: String
    var value: String
    var accent: Color = PulseTheme.textMain

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.textMuted)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PulseTheme.surfaceStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PulseTheme.line.opacity(0.7), lineWidth: 1)
                )
        )
    }
}
