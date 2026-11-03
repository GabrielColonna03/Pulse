import Foundation

struct UserProfile: Codable, Equatable {
    var displayName: String
    var isAdmin: Bool
    var needsOnboarding: Bool
}

struct LoginResponse: Codable {
    var displayName: String
    var token: String
    var expiresAt: Double?
}

struct APIErrorBody: Codable {
    var error: String?
}

struct Transaction: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var date: String
    var description: String
    var parentCategory: String
    var category: String
    var type: String
    var amount: Double
    var tripId: String
    var tripName: String?
    var createdAt: Double?

    var isExpense: Bool { type == "expense" }
    var isIncome: Bool { type == "income" }

    var signedAmount: Double { isExpense ? -amount : amount }

    var dateValue: Date {
        Self.dayFormatter.date(from: date) ?? Date()
    }

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dayString(from date: Date) -> String {
        dayFormatter.string(from: date)
    }
}

struct Trip: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var name: String
    var archived: Bool?
    var createdAt: Double?
}

struct CategoryKeyword: Codable, Equatable, Hashable, Identifiable {
    var id: String { name }
    var name: String
    var keywords: [String]
}

struct CategoryGroup: Codable, Equatable, Hashable, Identifiable {
    var id: String { name }
    var name: String
    var subcategories: [CategoryKeyword]
}

struct CategoryModel: Codable, Equatable {
    var income: [CategoryGroup]
    var expense: [CategoryGroup]

    static let `default` = CategoryModel(
        income: [
            CategoryGroup(name: "Income", subcategories: [
                CategoryKeyword(name: "Salary", keywords: ["paycheck", "salary"]),
                CategoryKeyword(name: "Other Income", keywords: ["bonus", "refund", "reimbursement"])
            ])
        ],
        expense: [
            CategoryGroup(name: "Personal", subcategories: [
                CategoryKeyword(name: "Food", keywords: ["food", "restaurant"]),
                CategoryKeyword(name: "Shopping", keywords: ["shopping", "amazon"]),
                CategoryKeyword(name: "Other", keywords: ["other", "misc"])
            ]),
            CategoryGroup(name: "Expenses", subcategories: [
                CategoryKeyword(name: "Groceries", keywords: ["grocery", "publix"]),
                CategoryKeyword(name: "Memberships", keywords: ["membership", "subscription"]),
                CategoryKeyword(name: "Necessities", keywords: ["doctor", "pharmacy"])
            ]),
            CategoryGroup(name: "Travel", subcategories: [
                CategoryKeyword(name: "Hotel", keywords: ["hotel", "airbnb"]),
                CategoryKeyword(name: "Flights", keywords: ["flight", "airfare"]),
                CategoryKeyword(name: "Transportation", keywords: ["uber", "lyft"])
            ])
        ]
    )

    var isValid: Bool {
        !income.isEmpty && income.allSatisfy { !$0.subcategories.isEmpty }
            && !expense.isEmpty && expense.allSatisfy { !$0.subcategories.isEmpty }
    }

    func groups(for type: String) -> [CategoryGroup] {
        type == "income" ? income : expense
    }

    mutating func setGroups(_ groups: [CategoryGroup], for type: String) {
        if type == "income" {
            income = groups
        } else {
            expense = groups
        }
    }

    func classify(description: String, type: String) -> (parent: String, category: String)? {
        let haystack = description.lowercased()
        for group in groups(for: type) {
            for sub in group.subcategories {
                if sub.keywords.contains(where: { haystack.contains($0.lowercased()) }) {
                    return (group.name, sub.name)
                }
            }
        }
        return nil
    }
}

struct CategoryModelEnvelope: Codable {
    var model: CategoryModel
}

struct TransactionDraft: Equatable {
    var description: String = ""
    var amount: String = ""
    var type: String = "expense"
    var date: Date = Date()
    var parentCategory: String = ""
    var category: String = ""
    var tripId: String = ""
    var recurrenceFrequency: String = "none"
    var recurrenceCount: Int = 1
    var editingId: String?

    var amountValue: Double? {
        Double(amount.replacingOccurrences(of: ",", with: ""))
    }
}

struct CreateTransactionBody: Codable {
    var description: String
    var amount: Double
    var type: String
    var date: String
    var category: String
    var parentCategory: String
    var tripId: String
    var recurrenceFrequency: String?
    var recurrenceCount: Int?
}

struct UpdateTransactionBody: Codable {
    var description: String
    var amount: Double
    var type: String
    var date: String
    var category: String
    var parentCategory: String
    var tripId: String
}

struct CreateTripBody: Codable {
    var name: String
}

struct RenameTripBody: Codable {
    var name: String
}

struct ChangePinBody: Codable {
    var currentPin: String
    var newPin: String
}

struct CreateUserBody: Codable {
    var displayName: String
    var pin: String
}

struct ManagedUser: Codable, Identifiable, Equatable {
    var id: String
    var displayName: String
    var isAdmin: Bool
    var isNew: Bool?
    var createdAt: Double?
}

struct SavingsGoal: Codable, Equatable {
    var name: String
    var targetAmount: Double
    var bufferMonths: Double

    static let `default` = SavingsGoal(name: "Emergency Fund", targetAmount: 5000, bufferMonths: 3)
}

struct MonthSummary: Equatable {
    var income: Double
    var spending: Double
    var net: Double
    var count: Int

    var savingsRate: Double {
        income > 0 ? (net / income) * 100 : 0
    }
}

enum PulseTab: String, CaseIterable, Identifiable {
    case home, insights, calendar, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .insights: return "Insights"
        case .calendar: return "Calendar"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .insights: return "chart.pie.fill"
        case .calendar: return "calendar"
        case .settings: return "gearshape.fill"
        }
    }
}
