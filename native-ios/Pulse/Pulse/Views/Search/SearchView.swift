import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Transaction] = []
    @State private var sort = "date-desc"
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            ZStack {
                PulseTheme.bgA.ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(PulseTheme.textMuted)
                            TextField("Search description…", text: $query)
                                .textInputAutocapitalization(.never)
                                .submitLabel(.search)
                                .onSubmit { Task { await runSearch() } }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))

                        Picker("Sort", selection: $sort) {
                            Text("Newest").tag("date-desc")
                            Text("Oldest").tag("date-asc")
                            Text("Amount ↓").tag("amount-desc")
                            Text("Amount ↑").tag("amount-asc")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: sort) { _, _ in results = sorted(results) }

                        Button {
                            Task { await runSearch() }
                        } label: {
                            HStack {
                                if isSearching { ProgressView().tint(.white) }
                                Text("Search")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(disabled: query.trimmingCharacters(in: .whitespaces).isEmpty || isSearching))
                    }
                    .padding()

                    List {
                        if results.isEmpty {
                            Text(query.isEmpty ? "Search across every month." : "No matches.")
                                .foregroundStyle(PulseTheme.textMuted)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(results) { tx in
                                MobileTransactionRow(
                                    transaction: tx,
                                    tripName: appState.tripName(for: tx),
                                    onEdit: {
                                        dismiss()
                                        appState.editTransaction(tx)
                                    },
                                    onDelete: {
                                        Task {
                                            await appState.deleteTransaction(tx)
                                            results.removeAll { $0.id == tx.id }
                                        }
                                    }
                                )
                                .listRowBackground(PulseTheme.surface)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task {
                                            await appState.deleteTransaction(tx)
                                            results.removeAll { $0.id == tx.id }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func runSearch() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            let found = try await APIClient.shared.searchTransactions(query: q)
            results = sorted(found)
            Haptics.light()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func sorted(_ items: [Transaction]) -> [Transaction] {
        switch sort {
        case "date-asc": return items.sorted { $0.dateValue < $1.dateValue }
        case "amount-desc": return items.sorted { $0.amount > $1.amount }
        case "amount-asc": return items.sorted { $0.amount < $1.amount }
        default: return items.sorted { $0.dateValue > $1.dateValue }
        }
    }
}
