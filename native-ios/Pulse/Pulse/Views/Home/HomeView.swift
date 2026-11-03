import SwiftUI

/// Mirrors mobile web Home (`renderMobilePage` → home): month switcher, monthly net hero,
/// income/spending/transactions/savings-rate grid, top categories with bars, latest 5 txs.
struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    private var month: MonthSummary { appState.monthSummary(for: appState.activeMonth) }
    private var categories: [(name: String, total: Double)] {
        Array(appState.parentExpenseTotals(for: appState.activeMonth).prefix(5))
    }
    private var maxCategory: Double { categories.map(\.total).max() ?? 1 }

    var body: some View {
        ZStack {
            PulseBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MobileMonthSwitcher(
                        kicker: "Overview",
                        title: appState.activeMonthLabel,
                        canGoForward: appState.monthOffset > 0,
                        onBack: { appState.shiftMonthBack() },
                        onForward: { appState.shiftMonthForward() },
                        onSearch: {
                            Haptics.light()
                            appState.showSearch = true
                        }
                    )

                    MobileHeroCard(
                        label: "Monthly net",
                        value: MoneyFormat.string(month.net),
                        accent: month.net >= 0 ? PulseTheme.green : PulseTheme.red
                    )

                    MobileSummaryGrid(items: [
                        .init(label: "Income", value: MoneyFormat.string(month.income)),
                        .init(label: "Spending", value: MoneyFormat.string(month.spending)),
                        .init(label: "Transactions", value: "\(appState.selectedMonthTransactions.count)"),
                        .init(label: "Savings rate", value: String(format: "%.0f%%", month.savingsRate))
                    ])

                    MobilePageCard(title: "Top categories", trailing: "\(appState.selectedMonthTransactions.count) entries") {
                        if categories.isEmpty {
                            Text("No spending recorded for this month.")
                                .foregroundStyle(PulseTheme.textMuted)
                                .font(.system(size: 14, design: .rounded))
                        } else {
                            ForEach(Array(categories.enumerated()), id: \.offset) { _, item in
                                MobileCategoryRow(name: item.name, total: item.total, maxTotal: maxCategory)
                            }
                        }
                    }

                    MobilePageCard(title: "Recent transactions", trailing: "Latest 5") {
                        if appState.recentTransactions.isEmpty {
                            Text("No transactions recorded yet.")
                                .foregroundStyle(PulseTheme.textMuted)
                                .font(.system(size: 14, design: .rounded))
                        } else {
                            ForEach(appState.recentTransactions) { tx in
                                MobileTransactionRow(
                                    transaction: tx,
                                    tripName: appState.tripName(for: tx),
                                    onEdit: { appState.editTransaction(tx) },
                                    onDelete: { Task { await appState.deleteTransaction(tx) } }
                                )
                                if tx.id != appState.recentTransactions.last?.id {
                                    Divider().overlay(PulseTheme.line.opacity(0.45))
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
}
