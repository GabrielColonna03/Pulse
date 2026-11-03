import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var isBootstrapping = true
    @Published var isAuthenticated = false
    @Published var isLocked = false
    @Published var profile: UserProfile?
    @Published var transactions: [Transaction] = []
    @Published var trips: [Trip] = []
    @Published var categoryModel: CategoryModel = .default
    @Published var selectedTab: PulseTab = .home
    @Published var selectedMonth: Date = Date()
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var showQuickAdd = false
    @Published var quickAddDraft = TransactionDraft()
    @Published var savingsGoal: SavingsGoal = .default
    @Published var apiBaseURL: String = ""
    @Published var biometricsEnabled: Bool = UserDefaults.standard.bool(forKey: SessionKeys.biometricsEnabled)
    @Published var isRefreshing = false

    private let savingsKey = "pulse.savingsGoal"

    init() {
        Task { await bootstrap() }
    }

    var displayName: String { profile?.displayName ?? "there" }
    var isAdmin: Bool { profile?.isAdmin == true }
    var needsOnboarding: Bool { profile?.needsOnboarding == true }

    var selectedMonthTransactions: [Transaction] {
        transactions.filter { Calendar.current.isDate($0.dateValue, equalTo: selectedMonth, toGranularity: .month) }
            .sorted { $0.dateValue > $1.dateValue }
    }

    var yearTransactions: [Transaction] {
        transactions.filter { Calendar.current.isDate($0.dateValue, equalTo: selectedMonth, toGranularity: .year) }
    }

    func monthSummary(for date: Date) -> MonthSummary {
        let txs = transactions.filter { Calendar.current.isDate($0.dateValue, equalTo: date, toGranularity: .month) }
        return summarize(txs)
    }

    func yearSummary(for date: Date) -> MonthSummary {
        let txs = transactions.filter { Calendar.current.isDate($0.dateValue, equalTo: date, toGranularity: .year) }
        return summarize(txs)
    }

    func parentExpenseTotals(for date: Date) -> [(name: String, total: Double)] {
        let expenses = transactions.filter {
            Calendar.current.isDate($0.dateValue, equalTo: date, toGranularity: .month) && $0.isExpense
        }
        var totals: [String: Double] = [:]
        for tx in expenses {
            let key = tx.parentCategory.isEmpty ? "Other" : tx.parentCategory
            totals[key, default: 0] += tx.amount
        }
        return totals.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }

    func topMerchants(limit: Int = 5) -> [(name: String, total: Double)] {
        var totals: [String: Double] = [:]
        for tx in yearTransactions where tx.isExpense {
            let key = tx.description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            totals[key, default: 0] += tx.amount
        }
        return totals.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }.prefix(limit).map { $0 }
    }

    func calendarGroups() -> [(date: Date, items: [Transaction])] {
        let grouped = Dictionary(grouping: selectedMonthTransactions) {
            Calendar.current.startOfDay(for: $0.dateValue)
        }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        isBootstrapping = true
        defer { isBootstrapping = false }

        let storedBase = UserDefaults.standard.string(forKey: SessionKeys.apiBase)
            ?? KeychainStore.get(SessionKeys.apiBase)
            ?? ""
        apiBaseURL = storedBase
        await APIClient.shared.configure(baseURL: storedBase)

        if let data = UserDefaults.standard.data(forKey: savingsKey),
           let goal = try? JSONDecoder().decode(SavingsGoal.self, from: data) {
            savingsGoal = goal
        }

        guard let token = await APIClient.shared.currentToken(), !token.isEmpty else {
            isAuthenticated = false
            return
        }

        do {
            profile = try await APIClient.shared.me()
            isAuthenticated = true
            if biometricsEnabled {
                isLocked = true
            } else {
                await refreshAll()
            }
        } catch {
            await APIClient.shared.setToken(nil)
            isAuthenticated = false
        }
    }

    func saveAPIBaseURL(_ value: String) async {
        apiBaseURL = value.trimmingCharacters(in: .whitespacesAndNewlines)
        await APIClient.shared.configure(baseURL: apiBaseURL)
    }

    func login(pin: String) async -> Bool {
        errorMessage = nil
        do {
            if apiBaseURL.isEmpty {
                errorMessage = "Add your API base URL first."
                return false
            }
            await APIClient.shared.configure(baseURL: apiBaseURL)
            let response = try await APIClient.shared.login(pin: pin)
            KeychainStore.set(response.displayName, forKey: SessionKeys.displayName)
            profile = try await APIClient.shared.me()
            isAuthenticated = true
            isLocked = false
            Haptics.success()
            await refreshAll()
            return true
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
            return false
        }
    }

    func logout() async {
        try? await APIClient.shared.logout()
        await APIClient.shared.setToken(nil)
        KeychainStore.delete(SessionKeys.displayName)
        isAuthenticated = false
        isLocked = false
        profile = nil
        transactions = []
        trips = []
        selectedTab = .home
    }

    func unlockWithBiometrics() async {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            isLocked = false
            await refreshAll()
            return
        }
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock Pulse"
            )
            if success {
                isLocked = false
                Haptics.success()
                await refreshAll()
            }
        } catch {
            errorMessage = "Could not unlock with Face ID / Touch ID."
        }
    }

    func setBiometricsEnabled(_ enabled: Bool) {
        biometricsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: SessionKeys.biometricsEnabled)
    }

    func handleScenePhase(_ phase: ScenePhase) {
        guard isAuthenticated, biometricsEnabled else { return }
        if phase == .background || phase == .inactive {
            isLocked = true
        }
    }

    func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            async let profileTask = APIClient.shared.me()
            async let txsTask = APIClient.shared.transactions()
            async let tripsTask = APIClient.shared.trips()
            async let modelTask = APIClient.shared.categoryModel()
            profile = try await profileTask
            transactions = try await txsTask
            trips = try await tripsTask
            categoryModel = try await modelTask
            statusMessage = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Mutations

    func submitQuickAdd(keepOpen: Bool) async -> Bool {
        guard let amount = quickAddDraft.amountValue, amount > 0 else {
            errorMessage = "Enter a valid amount."
            Haptics.error()
            return false
        }
        guard !quickAddDraft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Add a description."
            Haptics.error()
            return false
        }

        do {
            if let editingId = quickAddDraft.editingId {
                let body = UpdateTransactionBody(
                    description: quickAddDraft.description.trimmingCharacters(in: .whitespacesAndNewlines),
                    amount: amount,
                    type: quickAddDraft.type,
                    date: Transaction.dayString(from: quickAddDraft.date),
                    category: quickAddDraft.category,
                    parentCategory: quickAddDraft.parentCategory,
                    tripId: quickAddDraft.tripId
                )
                _ = try await APIClient.shared.updateTransaction(id: editingId, body: body)
            } else {
                let body = CreateTransactionBody(
                    description: quickAddDraft.description.trimmingCharacters(in: .whitespacesAndNewlines),
                    amount: amount,
                    type: quickAddDraft.type,
                    date: Transaction.dayString(from: quickAddDraft.date),
                    category: quickAddDraft.category,
                    parentCategory: quickAddDraft.parentCategory,
                    tripId: quickAddDraft.tripId,
                    recurrenceFrequency: quickAddDraft.recurrenceFrequency,
                    recurrenceCount: quickAddDraft.recurrenceCount
                )
                try await APIClient.shared.createTransaction(body)
            }
            Haptics.success()
            await refreshAll()
            if keepOpen {
                quickAddDraft.description = ""
                quickAddDraft.amount = ""
                quickAddDraft.editingId = nil
                applyCategorySuggestion()
            } else {
                showQuickAdd = false
                quickAddDraft = TransactionDraft()
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
            return false
        }
    }

    func editTransaction(_ tx: Transaction) {
        quickAddDraft = TransactionDraft(
            description: tx.description,
            amount: String(format: "%.2f", tx.amount),
            type: tx.type,
            date: tx.dateValue,
            parentCategory: tx.parentCategory,
            category: tx.category,
            tripId: tx.tripId,
            editingId: tx.id
        )
        showQuickAdd = true
    }

    func deleteTransaction(_ tx: Transaction) async {
        do {
            try await APIClient.shared.deleteTransaction(id: tx.id)
            Haptics.medium()
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }

    func applyCategorySuggestion() {
        if let match = categoryModel.classify(description: quickAddDraft.description, type: quickAddDraft.type) {
            quickAddDraft.parentCategory = match.parent
            quickAddDraft.category = match.category
        }
    }

    func shiftMonth(by value: Int) {
        if let date = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = date
            Haptics.selection()
        }
    }

    func saveCategoryModel(_ model: CategoryModel) async -> Bool {
        do {
            categoryModel = try await APIClient.shared.saveCategoryModel(model)
            profile = try await APIClient.shared.me()
            Haptics.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
            return false
        }
    }

    func createTrip(named name: String) async {
        do {
            _ = try await APIClient.shared.createTrip(name: name)
            await refreshAll()
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameTrip(_ trip: Trip, to name: String) async {
        do {
            _ = try await APIClient.shared.renameTrip(id: trip.id, name: name)
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTrip(_ trip: Trip) async {
        do {
            try await APIClient.shared.deleteTrip(id: trip.id)
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveSavingsGoal(_ goal: SavingsGoal) {
        savingsGoal = goal
        if let data = try? JSONEncoder().encode(goal) {
            UserDefaults.standard.set(data, forKey: savingsKey)
        }
    }

    func clearAllData() async {
        do {
            try await APIClient.shared.clearTransactions()
            await refreshAll()
            Haptics.medium()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func changePin(current: String, newPin: String) async -> Bool {
        do {
            try await APIClient.shared.changePin(currentPin: current, newPin: newPin)
            Haptics.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
            return false
        }
    }

    private func summarize(_ txs: [Transaction]) -> MonthSummary {
        let income = txs.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        let spending = txs.filter(\.isExpense).reduce(0) { $0 + $1.amount }
        return MonthSummary(income: income, spending: spending, net: income - spending, count: txs.count)
    }
}
