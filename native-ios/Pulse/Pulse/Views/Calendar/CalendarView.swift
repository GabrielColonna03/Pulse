import SwiftUI

/// Mirrors mobile web Calendar: month switcher, spending/net summary, day-grouped rows.
struct CalendarView: View {
    @EnvironmentObject private var appState: AppState

    private var month: MonthSummary { appState.monthSummary(for: appState.activeMonth) }
    private var groups: [(date: Date, items: [Transaction])] { appState.calendarGroups() }

    var body: some View {
        ZStack {
            PulseBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MobileMonthSwitcher(
                        kicker: "Calendar",
                        title: appState.activeMonthLabel,
                        canGoForward: appState.monthOffset > 0,
                        onBack: { appState.shiftMonthBack() },
                        onForward: { appState.shiftMonthForward() }
                    )

                    MobileSummaryGrid(items: [
                        .init(label: "Spending", value: MoneyFormat.string(month.spending)),
                        .init(label: "Net", value: MoneyFormat.string(month.net))
                    ])

                    MobilePageCard(title: "Transactions", trailing: "\(appState.selectedMonthTransactions.count)") {
                        if groups.isEmpty {
                            Text("No transactions for this month.")
                                .foregroundStyle(PulseTheme.textMuted)
                                .font(.system(size: 14, design: .rounded))
                        } else {
                            ForEach(groups, id: \.date) { group in
                                dayBlock(group.date, items: group.items)
                                if group.date != groups.last?.date {
                                    Divider().overlay(PulseTheme.line.opacity(0.4)).padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 120)
            }
            .refreshable { await appState.refreshAll() }
        }
    }

    private func dayBlock(_ date: Date, items: [Transaction]) -> some View {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatter.string(from: date))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Text("\(items.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
            }
            ForEach(items) { tx in
                MobileTransactionRow(
                    transaction: tx,
                    tripName: appState.tripName(for: tx),
                    onEdit: { appState.editTransaction(tx) },
                    onDelete: { Task { await appState.deleteTransaction(tx) } }
                )
            }
        }
        .padding(.vertical, 4)
    }
}
