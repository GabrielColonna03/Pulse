import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var appState: AppState

    private var month: MonthSummary { appState.monthSummary(for: appState.selectedMonth) }
    private var groups: [(date: Date, items: [Transaction])] { appState.calendarGroups() }

    var body: some View {
        ZStack {
            PulseBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "Calendar", subtitle: "Day-by-day for the selected month")
                    MonthSwitcher()

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricTile(label: "Spending", value: MoneyFormat.string(month.spending), accent: PulseTheme.pink)
                        MetricTile(label: "Net", value: MoneyFormat.string(month.net), accent: month.net >= 0 ? PulseTheme.green : PulseTheme.red)
                    }

                    if groups.isEmpty {
                        PulseCard {
                            Text("No transactions logged this month.")
                                .foregroundStyle(PulseTheme.textMuted)
                        }
                    } else {
                        ForEach(groups, id: \.date) { group in
                            daySection(group.date, items: group.items)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .refreshable { await appState.refreshAll() }
        }
    }

    private func daySection(_ date: Date, items: [Transaction]) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        let daySpend = items.filter(\.isExpense).reduce(0) { $0 + $1.amount }

        return PulseCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(formatter.string(from: date))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Spacer()
                    Text(MoneyFormat.string(daySpend))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PulseTheme.textMuted)
                }
                ForEach(items) { tx in
                    TransactionRowView(
                        transaction: tx,
                        onEdit: { appState.editTransaction(tx) },
                        onDelete: { Task { await appState.deleteTransaction(tx) } }
                    )
                }
            }
        }
    }
}
