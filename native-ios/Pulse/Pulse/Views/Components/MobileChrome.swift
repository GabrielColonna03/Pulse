import SwiftUI

/// Shared chrome that mirrors the mobile web (`renderMobilePage`) layout.

struct MobilePageKicker: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(PulseTheme.textMuted)
    }
}

struct MobileMonthSwitcher: View {
    var kicker: String
    var title: String
    var canGoForward: Bool
    var onBack: () -> Void
    var onForward: () -> Void
    var onSearch: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                MobilePageKicker(text: kicker)
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textMain)
            }
            Spacer(minLength: 8)
            if let onSearch {
                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PulseTheme.textMain)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
            }
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PulseTheme.textMain)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }
            .buttonStyle(.plain)
            Button(action: onForward) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(canGoForward ? PulseTheme.textMain : PulseTheme.textMuted.opacity(0.35))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
        }
    }
}

struct MobilePageHeader: View {
    var kicker: String
    var title: String
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                MobilePageKicker(text: kicker)
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(PulseTheme.textMain)
            }
            Spacer()
            if let trailing { trailing }
        }
    }
}

struct MobileHeroCard: View {
    var label: String
    var value: String
    var accent: Color = PulseTheme.textMain

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(PulseTheme.textMuted)
            Text(value)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 48 / 255, green: 34 / 255, blue: 76 / 255).opacity(0.94),
                            Color(red: 18 / 255, green: 14 / 255, blue: 34 / 255).opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(PulseTheme.line.opacity(0.7), lineWidth: 1)
                )
        )
    }
}

struct MobileSummaryGrid: View {
    struct Item: Identifiable {
        var id: String { label }
        var label: String
        var value: String
    }

    var items: [Item]

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.label)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textMuted)
                    Text(item.value)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.textMain)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 26 / 255, green: 22 / 255, blue: 38 / 255).opacity(0.94))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
        }
    }
}

struct MobilePageCard<Content: View>: View {
    var title: String
    var trailing: String? = nil
    var trailingAction: (() -> Void)? = nil
    var trailingLabel: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                Spacer()
                if let trailingAction, let trailingLabel {
                    Button(trailingLabel, action: trailingAction)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(PulseTheme.pink)
                } else if let trailing {
                    Text(trailing)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(PulseTheme.textMuted)
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 26 / 255, green: 22 / 255, blue: 38 / 255).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct MobileCategoryRow: View {
    var name: String
    var total: Double
    var maxTotal: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                Spacer()
                Text(MoneyFormat.string(total))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(PulseTheme.primaryGradient)
                        .frame(width: max(8, geo.size.width * CGFloat(total / max(maxTotal, 1))))
                }
            }
            .frame(height: 7)
        }
        .padding(.vertical, 4)
    }
}

struct MobileTransactionRow: View {
    let transaction: Transaction
    var tripName: String?
    var onEdit: () -> Void
    var onDelete: () -> Void

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: transaction.dateValue)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textMain)
                    .lineLimit(1)
                Text("\(transaction.category.isEmpty ? "Uncategorized" : transaction.category) · \(dateLabel)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                if let tripName, !tripName.isEmpty {
                    Text("✈ \(tripName)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(PulseTheme.blue)
                        .lineLimit(1)
                }
                Text("\(transaction.isIncome ? "+" : "-")\(MoneyFormat.string(transaction.amount))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(transaction.isIncome ? PulseTheme.green : PulseTheme.textMain)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

struct MobileSettingsRow: View {
    var title: String
    var subtitle: String? = nil
    var isDestructive: Bool = false
    var disabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: {
            guard !disabled else { return }
            Haptics.selection()
            action()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(isDestructive ? PulseTheme.red : (disabled ? PulseTheme.textMuted : PulseTheme.textMain))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PulseTheme.textMuted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PulseTheme.textMuted.opacity(disabled ? 0.35 : 0.9))
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

struct MobileBackRow: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Spacer()
            }
            .foregroundStyle(PulseTheme.pink)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
