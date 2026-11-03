import SwiftUI

/// Mirrors mobile Trip Summary modal: filter by trip and list linked transactions.
struct TripSummaryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTripId = "all"

    private var filtered: [Transaction] {
        let base = appState.transactions.filter { !$0.tripId.isEmpty }
        let scoped = selectedTripId == "all" ? base : base.filter { $0.tripId == selectedTripId }
        return scoped.sorted { $0.dateValue > $1.dateValue }
    }

    private var spend: Double {
        filtered.filter(\.isExpense).reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PulseTheme.bgA.ignoresSafeArea()
                List {
                    Section {
                        Picker("Trip", selection: $selectedTripId) {
                            Text("All trips").tag("all")
                            ForEach(appState.trips) { trip in
                                Text(trip.name).tag(trip.id)
                            }
                        }
                        Text("Tracked spend: \(MoneyFormat.string(spend))")
                            .foregroundStyle(PulseTheme.textMuted)
                    }

                    Section("Transactions") {
                        if filtered.isEmpty {
                            Text("No trip-linked transactions yet.")
                                .foregroundStyle(PulseTheme.textMuted)
                        } else {
                            ForEach(filtered) { tx in
                                MobileTransactionRow(
                                    transaction: tx,
                                    tripName: appState.tripName(for: tx),
                                    onEdit: { appState.editTransaction(tx) },
                                    onDelete: { Task { await appState.deleteTransaction(tx) } }
                                )
                                .listRowBackground(PulseTheme.surface)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Trip Summary")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
