import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var draft: CategoryModel = .default
    @State private var selectedType = "expense"
    @State private var isSaving = false
    @State private var message = ""

    var body: some View {
        ZStack {
            PulseBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Image("PulseLogo").resizable().scaledToFit().frame(width: 36, height: 36)
                        Text("Pulse").font(PulseTheme.displayFont)
                    }

                    PulseCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Welcome to your workspace")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PulseTheme.pink)
                            Text("Let’s make Pulse yours.")
                                .font(PulseTheme.titleFont)
                            Text("Before you see your dashboard, choose the way you think about your money. Start with our recommendations, then rename, remove, or add anything.")
                                .foregroundStyle(PulseTheme.textMuted)
                        }
                    }

                    Picker("Type", selection: $selectedType) {
                        Text("Expenses").tag("expense")
                        Text("Income").tag("income")
                    }
                    .pickerStyle(.segmented)

                    ForEach(Array(draft.groups(for: selectedType).enumerated()), id: \.offset) { groupIndex, group in
                        PulseCard {
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("Parent category", text: bindingParentName(type: selectedType, index: groupIndex))
                                    .font(.headline)
                                ForEach(Array(group.subcategories.enumerated()), id: \.offset) { subIndex, _ in
                                    HStack {
                                        TextField("Subcategory", text: bindingSubName(type: selectedType, group: groupIndex, sub: subIndex))
                                        Button(role: .destructive) {
                                            removeSub(type: selectedType, group: groupIndex, sub: subIndex)
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                        }
                                    }
                                }
                                Button("+ Add subcategory") {
                                    addSub(type: selectedType, group: groupIndex)
                                }
                                .buttonStyle(GhostButtonStyle())
                            }
                        }
                    }

                    Button("+ Add parent category") {
                        addParent(type: selectedType)
                    }
                    .buttonStyle(GhostButtonStyle())

                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            if isSaving { ProgressView().tint(.white) }
                            Text("Save & Enter Pulse")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(disabled: isSaving || !draft.isValid))
                    .disabled(isSaving || !draft.isValid)

                    if !message.isEmpty {
                        Text(message).foregroundStyle(PulseTheme.textMuted)
                    }
                }
                .padding(18)
                .padding(.bottom, 40)
            }
        }
        .onAppear { draft = appState.categoryModel }
    }

    private func bindingParentName(type: String, index: Int) -> Binding<String> {
        Binding(
            get: { draft.groups(for: type)[index].name },
            set: { newValue in
                var groups = draft.groups(for: type)
                groups[index].name = newValue
                draft.setGroups(groups, for: type)
            }
        )
    }

    private func bindingSubName(type: String, group: Int, sub: Int) -> Binding<String> {
        Binding(
            get: { draft.groups(for: type)[group].subcategories[sub].name },
            set: { newValue in
                var groups = draft.groups(for: type)
                groups[group].subcategories[sub].name = newValue
                draft.setGroups(groups, for: type)
            }
        )
    }

    private func addParent(type: String) {
        var groups = draft.groups(for: type)
        groups.append(CategoryGroup(name: "New Category", subcategories: [CategoryKeyword(name: "General", keywords: [])]))
        draft.setGroups(groups, for: type)
        Haptics.light()
    }

    private func addSub(type: String, group: Int) {
        var groups = draft.groups(for: type)
        groups[group].subcategories.append(CategoryKeyword(name: "New", keywords: []))
        draft.setGroups(groups, for: type)
        Haptics.light()
    }

    private func removeSub(type: String, group: Int, sub: Int) {
        var groups = draft.groups(for: type)
        guard groups[group].subcategories.count > 1 else { return }
        groups[group].subcategories.remove(at: sub)
        draft.setGroups(groups, for: type)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let ok = await appState.saveCategoryModel(draft)
        message = ok ? "You're in." : (appState.errorMessage ?? "Could not save")
    }
}
