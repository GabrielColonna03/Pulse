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
    /// Matches mobile web `state.monthOffset` (0 = current month; higher = further back).
    @Published var monthOffset: Int = 0
    /// Matches mobile web `state.insightsYearOffset` (0 = current year).
    @Published var insightsYearOffset: Int = 0
    @Published var settingsView: SettingsPane = .root
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var showQuickAdd = false
    @Published var showSearch = false
    @Published var showTrips = false
    @Published var showTripSummary = false
    @Published var showCategories = false
    @Published var showUsers = false
    @Published var showSavings = false
    @Published var showAPI = false
    @Published var showChangePin = false
    @Published var quickAddDraft = TransactionDraft()
    @Published var savingsGoal: SavingsGoal = .default
    @Published var apiBaseURL: String = ""
    @Published var biometricsEnabled: Bool = UserDefaults.standard.bool(forKey: SessionKeys.biometricsEnabled)
    @Published var isRefreshing = false

    private let savingsKey = "pulse.savingsGoal"

    enum SettingsPane: String {
        case root, general, data, travel
    }

    struct InsightMerchant: Identifiable, Equatable {
        var id: String { name + String(total) }
        var name: String
        var total: Double
        var count: Int
    }

    struct InsightSubcategory: Identifiable, Equatable {
        var id: String { name }
        var name: String
        var total: Double
        var count: Int
        var merchants: [InsightMerchant]
    }

    struct InsightGroup: Identifiable, Equatable {
        var id: String { name }
        var name: String
        var total: Double
        var subcategories: [InsightSubcategory]
    }

    init() {
        Task { await bootstrap() }
    }

    var displayName: String { profile?.displayName ?? "there" }
    var isAdmin: Bool { profile?.isAdmin == true }
    var needsOnboarding: Bool { profile?.needsOnboarding == true }

    var activeMonth: Date {
        Calendar.current.date(byAdding: .month, value: -monthOffset, to: Date()) ?? Date()
    }

    var insightsYear: Date {
        Calendar.current.date(byAdding: .year, value: -insightsYearOffset, to: Date()) ?? Date()
    }

    var activeMonthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: activeMonth)
    }

    var insightsYearLabel: String {
        let year = Calendar.current.component(.year, from: insightsYear)
        return "\(year) summary"
    }

    var selectedMonthTransactions: [Transaction] {
        transactions
            .filter { Calendar.current.isDate($0.dateValue, equalTo: activeMonth, toGranularity: .month) }
            .sorted {
                let left = $0.createdAt ?? 0
                let right = $1.createdAt ?? 0
                if left != right { return left > right }
                return $0.dateValue > $1.dateValue
            }
    }

    /// Mobile Home "Recent transactions" uses latest 5 across all months by createdAt.
    var recentTransactions: [Transaction] {
        Array(
            transactions
                .sorted {
                    let left = $0.createdAt ?? 0
                    let right = $1.createdAt ?? 0
                    if left != right { return left > right }
                    return $0.dateValue > $1.dateValue
                }
                .prefix(5)
        )
    }

    var yearTransactions: [Transaction] {
        let year = Calendar.current.component(.year, from: insightsYear)
        return transactions.filter {
            Calendar.current.component(.year, from: $0.dateValue) == year
        }
    }

    func monthSummary(for date: Date) -> MonthSummary {
        let txs = transactions.filter { Calendar.current.isDate($0.dateValue, equalTo: date, toGranularity: .month) }
        return summarize(txs)
    }

    func yearSummary(for date: Date) -> MonthSummary {
        let year = Calendar.current.component(.year, from: date)
        let txs = transactions.filter { Calendar.current.component(.year, from: $0.dateValue) == year }
        return summarize(txs)
    }

    func parentExpenseTotals(for date: Date) -> [(name: String, total: Double)] {
        let expenses = transactions.filter {
            Calendar.current.isDate($0.dateValue, equalTo: date, toGranularity: .month) && $0.isExpense
        }
        var totals: [String: Double] = [:]
        for tx in expenses {
            let key = tx.parentCategory.isEmpty ? "Expenses" : tx.parentCategory
            totals[key, default: 0] += tx.amount
        }
        return totals.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }

    func insightGroups() -> [InsightGroup] {
        var groups: [String: (total: Double, subs: [String: (total: Double, count: Int, merchants: [String: (name: String, total: Double, count: Int)])])] = [:]

        for tx in yearTransactions where tx.isExpense {
            let parent = tx.parentCategory.isEmpty ? "Expenses" : tx.parentCategory
            let sub = tx.category.isEmpty ? "Other" : tx.category
            let merchantKey = mobileMerchantKey(tx.description)
            var group = groups[parent] ?? (0, [:])
            group.total += tx.amount
            var subcategory = group.subs[sub] ?? (0, 0, [:])
            subcategory.total += tx.amount
            subcategory.count += 1
            var merchant = subcategory.merchants[merchantKey] ?? (tx.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Uncategorized" : tx.description.trimmingCharacters(in: .whitespacesAndNewlines), 0, 0)
            merchant.total += tx.amount
            merchant.count += 1
            subcategory.merchants[merchantKey] = merchant
            group.subs[sub] = subcategory
            groups[parent] = group
        }

        return groups.map { parent, value in
            InsightGroup(
                name: parent,
                total: value.total,
                subcategories: value.subs.map { name, sub in
                    InsightSubcategory(
                        name: name,
                        total: sub.total,
                        count: sub.count,
                        merchants: sub.merchants.values
                            .map { InsightMerchant(name: $0.name, total: $0.total, count: $0.count) }
                            .sorted { $0.total > $1.total }
                    )
                }
                .sorted { $0.total > $1.total }
            )
        }
        .sorted { $0.total > $1.total }
    }

    func tripName(for transaction: Transaction) -> String? {
        guard !transaction.tripId.isEmpty else { return nil }
        if let embedded = transaction.tripName, !embedded.isEmpty { return embedded }
        return trips.first(where: { $0.id == transaction.tripId })?.name
    }

    func calendarGroups() -> [(date: Date, items: [Transaction])] {
        let grouped = Dictionary(grouping: selectedMonthTransactions) {
            Calendar.current.startOfDay(for: $0.dateValue)
        }
        return grouped.keys.sorted(by: >).map { day in
            (day, (grouped[day] ?? []).sorted { $0.dateValue > $1.dateValue })
        }
    }

    private func mobileMerchantKey(_ description: String) -> String {
        let lowered = description.lowercased()
        let stripped = lowered
            .replacingOccurrences(of: #"\b(transaction|purchase|payment|pos|online|www)\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[#*]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\b\d{2,}\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? "uncategorized" : stripped
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
        settingsView = .root
        monthOffset = 0
        insightsYearOffset = 0
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

    /// Mobile web: previous-month increases offset; next-month decreases and stops at 0.
    func shiftMonthBack() {
        monthOffset += 1
        Haptics.selection()
    }

    func shiftMonthForward() {
        guard monthOffset > 0 else { return }
        monthOffset -= 1
        Haptics.selection()
    }

    func shiftYearBack() {
        insightsYearOffset += 1
        Haptics.selection()
    }

    func shiftYearForward() {
        guard insightsYearOffset > 0 else { return }
        insightsYearOffset -= 1
        Haptics.selection()
    }

    func openSettingsPane(_ pane: SettingsPane) {
        settingsView = pane
        Haptics.selection()
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
