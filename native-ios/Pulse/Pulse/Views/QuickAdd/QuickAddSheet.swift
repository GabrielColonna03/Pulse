import SwiftUI

struct QuickAddSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false

    private var groups: [CategoryGroup] {
        appState.categoryModel.groups(for: appState.quickAddDraft.type)
    }

    private var subcategories: [CategoryKeyword] {
        groups.first(where: { $0.name == appState.quickAddDraft.parentCategory })?.subcategories ?? []
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PulseTheme.bgA.ignoresSafeArea()
                Form {
                    Section("Basics") {
                        Picker("Type", selection: $appState.quickAddDraft.type) {
                            Text("Expense").tag("expense")
                            Text("Income").tag("income")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: appState.quickAddDraft.type) { _, _ in
                            syncDefaultCategories()
                            appState.applyCategorySuggestion()
                        }

                        TextField("Description", text: $appState.quickAddDraft.description)
                            .onChange(of: appState.quickAddDraft.description) { _, _ in
                                appState.applyCategorySuggestion()
                            }

                        TextField("Amount", text: $appState.quickAddDraft.amount)
                            .keyboardType(.decimalPad)

                        DatePicker("Date", selection: $appState.quickAddDraft.date, displayedComponents: .date)
                    }

                    Section("Category") {
                        Picker("Parent", selection: $appState.quickAddDraft.parentCategory) {
                            ForEach(groups) { group in
                                Text(group.name).tag(group.name)
                            }
                        }
                        .onChange(of: appState.quickAddDraft.parentCategory) { _, _ in
                            if let first = subcategories.first {
                                appState.quickAddDraft.category = first.name
                            }
                        }

                        Picker("Subcategory", selection: $appState.quickAddDraft.category) {
                            ForEach(subcategories) { sub in
                                Text(sub.name).tag(sub.name)
                            }
                        }
                    }

                    Section("Trip & recurrence") {
                        Picker("Trip", selection: $appState.quickAddDraft.tripId) {
                            Text("No trip").tag("")
                            ForEach(appState.trips) { trip in
                                Text(trip.name).tag(trip.id)
                            }
                        }

                        if appState.quickAddDraft.editingId == nil {
                            Picker("Repeat", selection: $appState.quickAddDraft.recurrenceFrequency) {
                                Text("None").tag("none")
                                Text("Weekly").tag("weekly")
                                Text("Biweekly").tag("biweekly")
                                Text("Monthly").tag("monthly")
                            }
                            if appState.quickAddDraft.recurrenceFrequency != "none" {
                                Stepper("Count: \(appState.quickAddDraft.recurrenceCount)", value: $appState.quickAddDraft.recurrenceCount, in: 1...36)
                            }
                        }
                    }

                    Section {
                        Button {
                            Task { await save(keepOpen: false) }
                        } label: {
                            HStack {
                                if isSaving { ProgressView() }
                                Text(appState.quickAddDraft.editingId == nil ? "Add transaction" : "Save changes")
                            }
                        }
                        .disabled(isSaving)

                        if appState.quickAddDraft.editingId == nil {
                            Button("Add & new") {
                                Task { await save(keepOpen: true) }
                            }
                            .disabled(isSaving)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(appState.quickAddDraft.editingId == nil ? "Quick Add" : "Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        appState.showQuickAdd = false
                        dismiss()
                    }
                }
            }
            .onAppear { syncDefaultCategories() }
        }
        .preferredColorScheme(.dark)
    }

    private func syncDefaultCategories() {
        if appState.quickAddDraft.parentCategory.isEmpty || !groups.contains(where: { $0.name == appState.quickAddDraft.parentCategory }) {
            appState.quickAddDraft.parentCategory = groups.first?.name ?? ""
        }
        if appState.quickAddDraft.category.isEmpty || !subcategories.contains(where: { $0.name == appState.quickAddDraft.category }) {
            appState.quickAddDraft.category = subcategories.first?.name ?? ""
        }
    }

    private func save(keepOpen: Bool) async {
        isSaving = true
        defer { isSaving = false }
        let ok = await appState.submitQuickAdd(keepOpen: keepOpen)
        if ok && !keepOpen {
            dismiss()
        }
    }
}
