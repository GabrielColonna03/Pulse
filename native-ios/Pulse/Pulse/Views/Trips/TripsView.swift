import SwiftUI

struct TripsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var newTripName = ""
    @State private var renaming: Trip?
    @State private var renameText = ""
    @State private var selectedTripId = "all"

    private var filteredTransactions: [Transaction] {
        let base = appState.transactions.filter { !$0.tripId.isEmpty }
        if selectedTripId == "all" { return base.sorted { $0.dateValue > $1.dateValue } }
        return base.filter { $0.tripId == selectedTripId }.sorted { $0.dateValue > $1.dateValue }
    }

    private func total(for tripId: String) -> Double {
        appState.transactions.filter { $0.tripId == tripId }.reduce(0) { $0 + ($1.isExpense ? $1.amount : -$1.amount) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PulseTheme.bgA.ignoresSafeArea()
                List {
                    Section("Create trip") {
                        HStack {
                            TextField("Trip name", text: $newTripName)
                            Button("Add") {
                                let name = newTripName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !name.isEmpty else { return }
                                Task {
                                    await appState.createTrip(named: name)
                                    newTripName = ""
                                }
                            }
                        }
                    }

                    Section("Summary filter") {
                        Picker("Trip", selection: $selectedTripId) {
                            Text("All trips").tag("all")
                            ForEach(appState.trips) { trip in
                                Text(trip.name).tag(trip.id)
                            }
                        }
                        Text("Tracked spend: \(MoneyFormat.string(filteredTransactions.filter(\.isExpense).reduce(0) { $0 + $1.amount }))")
                            .foregroundStyle(PulseTheme.textMuted)
                    }

                    Section("Manage") {
                        ForEach(appState.trips) { trip in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(trip.name).fontWeight(.semibold)
                                Text("\(appState.transactions.filter { $0.tripId == trip.id }.count) entries · \(MoneyFormat.string(total(for: trip.id)))")
                                    .font(.footnote)
                                    .foregroundStyle(PulseTheme.textMuted)
                            }
                            .swipeActions {
                                Button("Rename") {
                                    renaming = trip
                                    renameText = trip.name
                                }
                                Button(role: .destructive) {
                                    Task { await appState.deleteTrip(trip) }
                                } label: { Text("Delete") }
                            }
                        }
                    }

                    Section("Linked transactions") {
                        if filteredTransactions.isEmpty {
                            Text("No trip-linked transactions yet.")
                                .foregroundStyle(PulseTheme.textMuted)
                        } else {
                            ForEach(filteredTransactions.prefix(40)) { tx in
                                TransactionRowView(
                                    transaction: tx,
                                    onEdit: { appState.editTransaction(tx) },
                                    onDelete: { Task { await appState.deleteTransaction(tx) } },
                                    showsSwipeActions: true
                                )
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Trips")
            .alert("Rename trip", isPresented: Binding(
                get: { renaming != nil },
                set: { if !$0 { renaming = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Save") {
                    if let trip = renaming {
                        Task { await appState.renameTrip(trip, to: renameText) }
                    }
                    renaming = nil
                }
                Button("Cancel", role: .cancel) { renaming = nil }
            }
        }
        .preferredColorScheme(.dark)
    }
}
