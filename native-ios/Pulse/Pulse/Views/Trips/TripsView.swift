import SwiftUI

struct TripsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var newTripName = ""
    @State private var renaming: Trip?
    @State private var renameText = ""

    private func total(for tripId: String) -> Double {
        appState.transactions
            .filter { $0.tripId == tripId }
            .reduce(0) { $0 + ($1.isExpense ? $1.amount : 0) }
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
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Trip management")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
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
