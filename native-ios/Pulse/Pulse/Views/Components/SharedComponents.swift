import SwiftUI
import Charts

struct MonthSwitcher: View {
    @EnvironmentObject private var appState: AppState

    private var title: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: appState.selectedMonth)
    }

    var body: some View {
        HStack {
            Button {
                appState.shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(PulseTheme.textMain)
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            Spacer()
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
            Spacer()
            Button {
                appState.shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(PulseTheme.textMain)
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
        }
    }
}

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

struct TransactionRowView: View {
    let transaction: Transaction
    var onEdit: () -> Void
    var onDelete: () -> Void
    /// Swipe actions only work when this row is hosted inside a `List`.
    var showsSwipeActions: Bool = false

    var body: some View {
        let row = HStack(spacing: 12) {
            Circle()
                .fill(transaction.isIncome ? PulseTheme.green.opacity(0.2) : PulseTheme.pink.opacity(0.18))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: transaction.isIncome ? "arrow.down.left" : "arrow.up.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(transaction.isIncome ? PulseTheme.green : PulseTheme.pink)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.description)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text("\(transaction.parentCategory) · \(transaction.category)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PulseTheme.textMuted)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text((transaction.isIncome ? "+" : "-") + MoneyFormat.string(transaction.amount))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(transaction.isIncome ? PulseTheme.green : PulseTheme.textMain)
                Text(transaction.date)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PulseTheme.textMuted)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .onTapGesture { onEdit() }

        if showsSwipeActions {
            row.swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(PulseTheme.purple)
            }
        } else {
            row
        }
    }
}

struct CategoryDonutChart: View {
    let totals: [(name: String, total: Double)]

    var body: some View {
        if totals.isEmpty {
            Text("No expense data this month")
                .foregroundStyle(PulseTheme.textMuted)
                .frame(maxWidth: .infinity, minHeight: 180)
        } else {
            Chart(Array(totals.enumerated()), id: \.offset) { index, item in
                SectorMark(
                    angle: .value("Amount", item.total),
                    innerRadius: .ratio(0.58),
                    angularInset: 1.5
                )
                .foregroundStyle(PulseTheme.chartColors[index % PulseTheme.chartColors.count])
                .cornerRadius(4)
            }
            .frame(height: 200)
            .chartLegend(.hidden)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(totals.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Circle()
                            .fill(PulseTheme.chartColors[index % PulseTheme.chartColors.count])
                            .frame(width: 8, height: 8)
                        Text(item.name)
                            .foregroundStyle(PulseTheme.textMuted)
                        Spacer()
                        Text(MoneyFormat.string(item.total))
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 13, design: .rounded))
                }
            }
        }
    }
}

struct ScreenHeader: View {
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image("PulseLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                Text(title)
                    .font(PulseTheme.titleFont)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PulseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
