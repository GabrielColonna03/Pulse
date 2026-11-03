import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var appState: AppState

    private var year: MonthSummary { appState.yearSummary(for: appState.selectedMonth) }
    private var monthTotals: [(name: String, total: Double)] {
        appState.parentExpenseTotals(for: appState.selectedMonth)
    }

    var body: some View {
        ZStack {
            PulseBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "Insights", subtitle: "Year-to-date and this month’s mix")
                    MonthSwitcher()

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricTile(label: "Year income", value: MoneyFormat.string(year.income), accent: PulseTheme.green)
                        MetricTile(label: "Year spending", value: MoneyFormat.string(year.spending), accent: PulseTheme.pink)
                        MetricTile(label: "Transactions", value: "\(year.count)")
                        MetricTile(label: "Savings rate", value: String(format: "%.0f%%", year.savingsRate), accent: PulseTheme.blue)
                    }

                    PulseCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Month expense mix")
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                            CategoryDonutChart(totals: monthTotals)
                        }
                    }

                    PulseCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Top merchants this year")
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                            let merchants = appState.topMerchants()
                            if merchants.isEmpty {
                                Text("Spend a little and merchants will show up here.")
                                    .foregroundStyle(PulseTheme.textMuted)
                            } else {
                                ForEach(Array(merchants.enumerated()), id: \.offset) { _, item in
                                    HStack {
                                        Text(item.name)
                                            .lineLimit(1)
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
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .refreshable { await appState.refreshAll() }
        }
    }
}
