import SwiftUI

/// Mirrors mobile web Insights: year switcher, year-net hero, dual stat grids,
/// expandable parent → subcategory → merchant spending breakdown (no donut chart).
struct InsightsView: View {
    @EnvironmentObject private var appState: AppState

    private var year: MonthSummary { appState.yearSummary(for: appState.insightsYear) }
    private var groups: [AppState.InsightGroup] { appState.insightGroups() }
    private var expenses: [Transaction] { appState.yearTransactions.filter(\.isExpense) }
    private var averageExpense: Double {
        expenses.isEmpty ? 0 : expenses.reduce(0) { $0 + $1.amount } / Double(expenses.count)
    }
    private var largestExpense: Transaction? {
        expenses.max(by: { $0.amount < $1.amount })
    }
    private var topMerchant: AppState.InsightMerchant? {
        groups.flatMap { $0.subcategories.flatMap(\.merchants) }.max(by: { $0.total < $1.total })
    }

    var body: some View {
        ZStack {
            PulseBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MobilePageHeader(
                        kicker: "Insights",
                        title: appState.insightsYearLabel,
                        trailing: AnyView(
                            HStack(spacing: 8) {
                                Button { appState.shiftYearBack() } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(width: 38, height: 38)
                                        .background(Circle().fill(Color.white.opacity(0.07)))
                                }
                                Button { appState.shiftYearForward() } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(appState.insightsYearOffset > 0 ? PulseTheme.textMain : PulseTheme.textMuted.opacity(0.35))
                                        .frame(width: 38, height: 38)
                                        .background(Circle().fill(Color.white.opacity(0.07)))
                                }
                                .disabled(appState.insightsYearOffset == 0)
                            }
                            .foregroundStyle(PulseTheme.textMain)
                            .buttonStyle(.plain)
                        )
                    )

                    MobileHeroCard(
                        label: "Year net",
                        value: MoneyFormat.string(year.net),
                        accent: year.net >= 0 ? PulseTheme.green : PulseTheme.red
                    )

                    MobileSummaryGrid(items: [
                        .init(label: "Year income", value: MoneyFormat.string(year.income)),
                        .init(label: "Year spending", value: MoneyFormat.string(year.spending)),
                        .init(label: "Transactions", value: "\(appState.yearTransactions.count)"),
                        .init(label: "Savings rate", value: String(format: "%.0f%%", year.savingsRate))
                    ])

                    MobileSummaryGrid(items: [
                        .init(label: "Avg. expense", value: MoneyFormat.string(averageExpense)),
                        .init(label: "Largest expense", value: largestExpense.map { MoneyFormat.string($0.amount) } ?? "—"),
                        .init(label: "Top merchant", value: topMerchant?.name ?? "—"),
                        .init(label: "Merchant total", value: topMerchant.map { MoneyFormat.string($0.total) } ?? "—")
                    ])

                    MobilePageCard(title: "Spending breakdown", trailing: "\(expenses.count) expenses") {
                        if groups.isEmpty {
                            Text("Add expense transactions to see category insights.")
                                .foregroundStyle(PulseTheme.textMuted)
                                .font(.system(size: 14, design: .rounded))
                        } else {
                            ForEach(groups) { group in
                                DisclosureGroup {
                                    ForEach(group.subcategories) { sub in
                                        DisclosureGroup {
                                            ForEach(Array(sub.merchants.prefix(5))) { merchant in
                                                HStack {
                                                    Text("\(merchant.name) ×\(merchant.count)")
                                                        .font(.system(size: 13, design: .rounded))
                                                        .foregroundStyle(PulseTheme.textMuted)
                                                        .lineLimit(1)
                                                    Spacer()
                                                    Text(MoneyFormat.string(merchant.total))
                                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                }
                                                .padding(.vertical, 4)
                                            }
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(sub.name).fontWeight(.semibold)
                                                    Text("\(sub.count) transactions")
                                                        .font(.caption)
                                                        .foregroundStyle(PulseTheme.textMuted)
                                                }
                                                Spacer()
                                                Text(MoneyFormat.string(sub.total))
                                                    .fontWeight(.semibold)
                                            }
                                            .font(.system(size: 14, design: .rounded))
                                        }
                                        .tint(PulseTheme.textMuted)
                                        .padding(.vertical, 4)
                                    }
                                } label: {
                                    HStack {
                                        Text(group.name).fontWeight(.semibold)
                                        Spacer()
                                        Text(MoneyFormat.string(group.total)).fontWeight(.bold)
                                    }
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundStyle(PulseTheme.textMain)
                                }
                                .tint(PulseTheme.pink)
                                .padding(.vertical, 4)

                                if group.id != groups.last?.id {
                                    Divider().overlay(PulseTheme.line.opacity(0.4))
                                }
                            }
                        }
                    }

                    MobilePageCard(
                        title: "Monthly snapshot",
                        trailingAction: { appState.selectedTab = .calendar },
                        trailingLabel: "View calendar"
                    ) {
                        Text("Use the calendar page to move through each month and review the transactions behind these totals.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(PulseTheme.textMuted)
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
