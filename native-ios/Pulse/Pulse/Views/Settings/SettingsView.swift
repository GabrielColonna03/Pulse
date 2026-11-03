import SwiftUI
import UniformTypeIdentifiers

/// Mirrors mobile web Settings drill-down: root → General / Data / Travel (+ Savings, Log out).
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var confirmClear = false
    @State private var newTripName = ""
    @State private var showCreateTrip = false
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var importPresented = false

    var body: some View {
        ZStack {
            PulseBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MobilePageHeader(kicker: "Pulse", title: "Settings")

                    MobilePageCard(title: paneTitle) {
                        switch appState.settingsView {
                        case .root: rootMenu
                        case .general: generalMenu
                        case .data: dataMenu
                        case .travel: travelMenu
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 120)
            }
        }
        .sheet(isPresented: $appState.showChangePin) { ChangePinSheet().environmentObject(appState) }
        .sheet(isPresented: $appState.showSavings) { SavingsGoalSheet().environmentObject(appState) }
        .sheet(isPresented: $appState.showUsers) { UserManagementView().environmentObject(appState) }
        .sheet(isPresented: $appState.showCategories) { CategoryEditorView().environmentObject(appState) }
        .sheet(isPresented: $appState.showAPI) { APISettingsSheet().environmentObject(appState) }
        .sheet(isPresented: $appState.showTrips) { TripsView().environmentObject(appState) }
        .sheet(isPresented: $appState.showTripSummary) { TripSummaryView().environmentObject(appState) }
        .sheet(isPresented: $showShare) {
            if let exportURL { ShareSheet(items: [exportURL]) }
        }
        .fileImporter(
            isPresented: $importPresented,
            allowedContentTypes: [.commaSeparatedText, .data] + [UTType(filenameExtension: "xlsx")].compactMap { $0 },
            allowsMultipleSelection: false
        ) { result in
            // Import preview pipeline remains server-driven; for now surface guidance.
            switch result {
            case .success:
                appState.errorMessage = "Import preview is available on the web app for now. Use Export/Backup here, or import from desktop Pulse."
            case .failure(let error):
                appState.errorMessage = error.localizedDescription
            }
        }
        .alert("Create trip", isPresented: $showCreateTrip) {
            TextField("Trip name", text: $newTripName)
            Button("Create") {
                let name = newTripName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                Task { await appState.createTrip(named: name) }
                newTripName = ""
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Clear all transactions?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear everything", role: .destructive) {
                Task { await appState.clearAllData() }
            }
        }
    }

    private var paneTitle: String {
        switch appState.settingsView {
        case .root: return "Menu"
        case .general: return "General"
        case .data: return "Data"
        case .travel: return "Travel"
        }
    }

    @ViewBuilder
    private var rootMenu: some View {
        MobileSettingsRow(title: "General") { appState.openSettingsPane(.general) }
        divider
        MobileSettingsRow(title: "Data") { appState.openSettingsPane(.data) }
        divider
        MobileSettingsRow(title: "Travel") { appState.openSettingsPane(.travel) }
        divider
        MobileSettingsRow(title: "Savings") { appState.showSavings = true }
        divider
        MobileSettingsRow(title: "Log out", isDestructive: true) {
            Task { await appState.logout() }
        }
    }

    @ViewBuilder
    private var generalMenu: some View {
        MobileBackRow(title: "General") { appState.openSettingsPane(.root) }
        divider
        MobileSettingsRow(title: "Category Management") { appState.showCategories = true }
        divider
        MobileSettingsRow(title: "Change PIN") { appState.showChangePin = true }
        divider
        MobileSettingsRow(title: "API base URL") { appState.showAPI = true }
        divider
        Toggle(isOn: Binding(
            get: { appState.biometricsEnabled },
            set: { appState.setBiometricsEnabled($0) }
        )) {
            Text("Lock with Face ID / Touch ID")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
        }
        .tint(PulseTheme.pink)
        .padding(.vertical, 8)
        divider
        MobileSettingsRow(title: "Link Financials", subtitle: "Coming soon", disabled: true) {}
        if appState.isAdmin {
            divider
            MobileSettingsRow(title: "User Management") { appState.showUsers = true }
        }
    }

    @ViewBuilder
    private var dataMenu: some View {
        MobileBackRow(title: "Data") { appState.openSettingsPane(.root) }
        divider
        MobileSettingsRow(title: "Import data") { importPresented = true }
        divider
        MobileSettingsRow(title: "Export data") { Task { await exportExcel() } }
        divider
        MobileSettingsRow(title: "Backup data") { Task { await exportCSV() } }
        divider
        MobileSettingsRow(title: "Clear all transactions", isDestructive: true) { confirmClear = true }
    }

    @ViewBuilder
    private var travelMenu: some View {
        MobileBackRow(title: "Travel") { appState.openSettingsPane(.root) }
        divider
        MobileSettingsRow(title: "Create new trip") { showCreateTrip = true }
        divider
        MobileSettingsRow(title: "Trip management") { appState.showTrips = true }
        divider
        MobileSettingsRow(title: "Trip summary") { appState.showTripSummary = true }
    }

    private var divider: some View {
        Divider().overlay(PulseTheme.line.opacity(0.45))
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
                    ProgressView(value: progress).tint(PulseTheme.pink)
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
