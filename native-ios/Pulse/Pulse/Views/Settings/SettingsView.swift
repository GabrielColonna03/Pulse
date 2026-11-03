import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showChangePin = false
    @State private var showSavings = false
    @State private var showUsers = false
    @State private var showCategories = false
    @State private var showAPI = false
    @State private var confirmClear = false
    @State private var exportURL: URL?
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            ZStack {
                PulseBackground()
                List {
                    Section {
                        HStack(spacing: 14) {
                            Image("PulseLogo").resizable().scaledToFit().frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(appState.displayName).font(.headline)
                                Text(appState.isAdmin ? "Admin · Private beta" : "Private beta")
                                    .foregroundStyle(PulseTheme.textMuted)
                                    .font(.footnote)
                            }
                        }
                        .listRowBackground(PulseTheme.surface)
                    }

                    Section("General") {
                        Button("Change PIN") { showChangePin = true }
                        Button("Edit categories") { showCategories = true }
                        Toggle("Lock with Face ID / Touch ID", isOn: Binding(
                            get: { appState.biometricsEnabled },
                            set: { appState.setBiometricsEnabled($0) }
                        ))
                        Button("API base URL") { showAPI = true }
                    }

                    Section("Travel & savings") {
                        NavigationLink("Manage trips") { TripsView().environmentObject(appState) }
                        Button("Savings goal") { showSavings = true }
                    }

                    Section("Data") {
                        Button("Export Excel") {
                            Task { await exportExcel() }
                        }
                        Button("Backup CSV") {
                            Task { await exportCSV() }
                        }
                        Button("Clear all transactions", role: .destructive) {
                            confirmClear = true
                        }
                    }

                    if appState.isAdmin {
                        Section("Admin") {
                            Button("User management") { showUsers = true }
                        }
                    }

                    Section {
                        Button("Log out", role: .destructive) {
                            Task { await appState.logout() }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showChangePin) { ChangePinSheet().environmentObject(appState) }
            .sheet(isPresented: $showSavings) { SavingsGoalSheet().environmentObject(appState) }
            .sheet(isPresented: $showUsers) { UserManagementView().environmentObject(appState) }
            .sheet(isPresented: $showCategories) { CategoryEditorView().environmentObject(appState) }
            .sheet(isPresented: $showAPI) { APISettingsSheet().environmentObject(appState) }
            .sheet(isPresented: $showShare) {
                if let exportURL {
                    ShareSheet(items: [exportURL])
                }
            }
            .confirmationDialog("Clear all transactions?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear everything", role: .destructive) {
                    Task { await appState.clearAllData() }
                }
            }
        }
    }

    private func exportExcel() async {
        do {
            let data = try await APIClient.shared.exportExcel()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("pulse-export.xlsx")
            try data.write(to: url)
            exportURL = url
            showShare = true
            Haptics.success()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func exportCSV() async {
        do {
            let data = try await APIClient.shared.exportBackupCSV()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("pulse-backup.csv")
            try data.write(to: url)
            exportURL = url
            showShare = true
            Haptics.success()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ChangePinSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var newPin = ""
    @State private var confirm = ""

    var body: some View {
        NavigationStack {
            Form {
                SecureField("Current PIN", text: $current).keyboardType(.numberPad)
                SecureField("New PIN", text: $newPin).keyboardType(.numberPad)
                SecureField("Confirm new PIN", text: $confirm).keyboardType(.numberPad)
            }
            .navigationTitle("Change PIN")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            guard newPin == confirm, newPin.count == 4 else {
                                appState.errorMessage = "New PIN must be 4 matching digits."
                                return
                            }
                            if await appState.changePin(current: current, newPin: newPin) {
                                dismiss()
                            }
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct SavingsGoalSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var target = ""
    @State private var buffer = ""

    private var progress: Double {
        let year = appState.yearSummary(for: Date())
        let targetValue = Double(target) ?? appState.savingsGoal.targetAmount
        guard targetValue > 0 else { return 0 }
        return min(max(year.net / targetValue, 0), 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Goal name", text: $name)
                TextField("Target amount", text: $target).keyboardType(.decimalPad)
                TextField("Buffer months", text: $buffer).keyboardType(.decimalPad)
                Section("Progress") {
                    ProgressView(value: progress)
                        .tint(PulseTheme.pink)
                    Text("Based on year-to-date net: \(MoneyFormat.string(appState.yearSummary(for: Date()).net))")
                        .foregroundStyle(PulseTheme.textMuted)
                }
            }
            .navigationTitle("Savings goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let goal = SavingsGoal(
                            name: name.isEmpty ? "Emergency Fund" : name,
                            targetAmount: Double(target) ?? 5000,
                            bufferMonths: Double(buffer) ?? 3
                        )
                        appState.saveSavingsGoal(goal)
                        Haptics.success()
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = appState.savingsGoal.name
                target = String(format: "%.0f", appState.savingsGoal.targetAmount)
                buffer = String(format: "%.0f", appState.savingsGoal.bufferMonths)
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct CategoryEditorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CategoryModel = .default
    @State private var type = "expense"

    var body: some View {
        NavigationStack {
            List {
                Picker("Type", selection: $type) {
                    Text("Expense").tag("expense")
                    Text("Income").tag("income")
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                ForEach(Array(draft.groups(for: type).enumerated()), id: \.offset) { groupIndex, group in
                    Section(group.name) {
                        ForEach(Array(group.subcategories.enumerated()), id: \.offset) { subIndex, sub in
                            Text(sub.name)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        var groups = draft.groups(for: type)
                                        guard groups[groupIndex].subcategories.count > 1 else { return }
                                        groups[groupIndex].subcategories.remove(at: subIndex)
                                        draft.setGroups(groups, for: type)
                                    } label: { Text("Delete") }
                                }
                        }
                        Button("Add subcategory") {
                            var groups = draft.groups(for: type)
                            groups[groupIndex].subcategories.append(CategoryKeyword(name: "New", keywords: []))
                            draft.setGroups(groups, for: type)
                        }
                    }
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await appState.saveCategoryModel(draft) { dismiss() }
                        }
                    }
                }
            }
            .onAppear { draft = appState.categoryModel }
        }
        .preferredColorScheme(.dark)
    }
}

struct UserManagementView: View {
    @EnvironmentObject private var appState: AppState
    @State private var users: [ManagedUser] = []
    @State private var displayName = ""
    @State private var pin = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Create user") {
                    TextField("Display name", text: $displayName)
                    SecureField("4-digit PIN", text: $pin).keyboardType(.numberPad)
                    Button("Create") {
                        Task {
                            _ = try? await APIClient.shared.createUser(displayName: displayName, pin: pin)
                            displayName = ""; pin = ""
                            await reload()
                        }
                    }
                }
                Section("Users") {
                    ForEach(users) { user in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName).fontWeight(.semibold)
                            Text(user.isAdmin ? "Admin" : "Member")
                                .font(.footnote)
                                .foregroundStyle(PulseTheme.textMuted)
                        }
                        .swipeActions {
                            if !user.isAdmin {
                                Button("Reset onboarding") {
                                    Task {
                                        try? await APIClient.shared.resetOnboarding(userId: user.id)
                                        await reload()
                                    }
                                }
                                Button(role: .destructive) {
                                    Task {
                                        try? await APIClient.shared.deleteUser(userId: user.id)
                                        await reload()
                                    }
                                } label: { Text("Delete") }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Users")
            .task { await reload() }
        }
        .preferredColorScheme(.dark)
    }

    private func reload() async {
        users = (try? await APIClient.shared.users()) ?? []
    }
}
