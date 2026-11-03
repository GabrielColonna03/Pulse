import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    var onSearch: () -> Void
    var onTrips: () -> Void

    private var month: MonthSummary { appState.monthSummary(for: appState.selectedMonth) }
    private var year: MonthSummary { appState.yearSummary(for: appState.selectedMonth) }
    private var topCategories: [(name: String, total: Double)] {
        Array(appState.parentExpenseTotals(for: appState.selectedMonth).prefix(4))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PulseBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        MonthSwitcher()
                        netHero
                        summaryGrid
                        topCategoriesSection
                        recentSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
                .refreshable {
                    await appState.refreshAll()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PulseTheme.textMuted)
                Text(appState.displayName)
                    .font(PulseTheme.titleFont)
            }
            Spacer()
            HStack(spacing: 10) {
                Button(action: onSearch) {
                    Image(systemName: "magnifyingglass")
                        .padding(10)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                }
                Button(action: onTrips) {
                    Image(systemName: "suitcase.fill")
                        .padding(10)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                }
            }
            .foregroundStyle(PulseTheme.textMain)
        }
    }

    private var netHero: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("This month’s net")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PulseTheme.textMuted)
                Text(MoneyFormat.string(month.net))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(month.net >= 0 ? PulseTheme.green : PulseTheme.red)
                Text("Income \(MoneyFormat.string(month.income)) · Spending \(MoneyFormat.string(month.spending))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PulseTheme.textMuted)
            }
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(label: "Year income", value: MoneyFormat.string(year.income), accent: PulseTheme.green)
            MetricTile(label: "Year spending", value: MoneyFormat.string(year.spending), accent: PulseTheme.pink)
            MetricTile(label: "Year net", value: MoneyFormat.string(year.net), accent: year.net >= 0 ? PulseTheme.green : PulseTheme.red)
            MetricTile(label: "Savings rate", value: String(format: "%.0f%%", year.savingsRate), accent: PulseTheme.blue)
        }
    }

    private var topCategoriesSection: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top categories")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                if topCategories.isEmpty {
                    Text("Add an expense to see categories here.")
                        .foregroundStyle(PulseTheme.textMuted)
                } else {
                    ForEach(Array(topCategories.enumerated()), id: \.offset) { index, item in
                        HStack {
                            Circle()
                                .fill(PulseTheme.chartColors[index % PulseTheme.chartColors.count])
                                .frame(width: 8, height: 8)
                            Text(item.name)
                            Spacer()
                            Text(MoneyFormat.string(item.total))
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 14, design: .rounded))
                    }
                }
            }
        }
    }

    private var recentSection: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent entries")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                    Spacer()
                    Text("\(appState.selectedMonthTransactions.count)")
                        .foregroundStyle(PulseTheme.textMuted)
                        .font(.footnote)
                }
                if appState.selectedMonthTransactions.isEmpty {
                    Text("No transactions this month yet.")
                        .foregroundStyle(PulseTheme.textMuted)
                } else {
                    ForEach(Array(appState.selectedMonthTransactions.prefix(8))) { tx in
                        TransactionRowView(
                            transaction: tx,
                            onEdit: { appState.editTransaction(tx) },
                            onDelete: { Task { await appState.deleteTransaction(tx) } }
                        )
                        if tx.id != appState.selectedMonthTransactions.prefix(8).last?.id {
                            Divider().overlay(PulseTheme.line.opacity(0.5))
                        }
                    }
                }
            }
        }
    }
}
