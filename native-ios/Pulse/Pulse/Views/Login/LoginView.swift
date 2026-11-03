import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var digits: [String] = ["", "", "", ""]
    @State private var focusedIndex = 0
    @State private var isSubmitting = false
    @State private var showAPISettings = false
    @FocusState private var focusField: Int?

    private var pin: String { digits.joined() }

    var body: some View {
        NavigationStack {
            ZStack {
                PulseBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        brandHeader
                        introCopy
                        pinCard
                    }
                    .padding(24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAPISettings = true
                    } label: {
                        Image(systemName: "server.rack")
                            .foregroundStyle(PulseTheme.textMuted)
                    }
                    .accessibilityLabel("API settings")
                }
            }
            .sheet(isPresented: $showAPISettings) {
                APISettingsSheet()
                    .environmentObject(appState)
                    .presentationDetents([.medium])
            }
            .onAppear {
                focusField = 0
            }
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 12) {
            Image("PulseLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
            Text("Pulse")
                .font(PulseTheme.displayFont)
        }
    }

    private var introCopy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Private beta · By invitation")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(PulseTheme.pink)
            Text("You’re in the room early.")
                .font(PulseTheme.titleFont)
            Text("Pulse is being shaped with a small group of thoughtful testers. Enter your 4-digit PIN to open your private dashboard.")
                .foregroundStyle(PulseTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pinCard: some View {
        PulseCard(padding: 22) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Pulse · Founding tester access")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.textMuted)
                Text("Welcome to the beta.")
                    .font(PulseTheme.sectionFont)
                Text("Security PIN")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PulseTheme.textMuted)

                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { index in
                        TextField("", text: binding(for: index))
                            .keyboardType(.numberPad)
                            .textContentType(index == 0 ? .oneTimeCode : .none)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .frame(height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.black.opacity(0.28))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(focusField == index ? PulseTheme.purple : PulseTheme.line, lineWidth: 1.5)
                                    )
                            )
                            .focused($focusField, equals: index)
                            .onChange(of: digits[index]) { _, newValue in
                                handleDigitChange(index: index, value: newValue)
                            }
                    }
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        if isSubmitting { ProgressView().tint(.white) }
                        Text(isSubmitting ? "Verifying…" : "Continue to dashboard →")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(disabled: pin.count < 4 || isSubmitting))
                .disabled(pin.count < 4 || isSubmitting)

                if appState.apiBaseURL.isEmpty {
                    Text("Tip: tap the server icon to set your API URL (e.g. https://your-backend.onrender.com).")
                        .font(.footnote)
                        .foregroundStyle(PulseTheme.textMuted)
                }

                Text("Private beta · Built with our original testers")
                    .font(.footnote)
                    .foregroundStyle(PulseTheme.textMuted)
            }
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { digits[index] },
            set: { digits[index] = String($0.filter(\.isNumber).prefix(1)) }
        )
    }

    private func handleDigitChange(index: Int, value: String) {
        Haptics.light()
        if value.count == 1, index < 3 {
            focusField = index + 1
        } else if value.isEmpty, index > 0 {
            focusField = index - 1
        } else if pin.count == 4 {
            Task { await submit() }
        }
    }

    private func submit() async {
        guard pin.count == 4, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        _ = await appState.login(pin: pin)
        if !appState.isAuthenticated {
            digits = ["", "", "", ""]
            focusField = 0
        }
    }
}

struct APISettingsSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var testing = false
    @State private var testResult: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Backend") {
                    TextField("https://your-api.example.com", text: $draft)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                }
                Section {
                    Button(testing ? "Testing…" : "Test connection") {
                        Task { await test() }
                    }
                    .disabled(testing || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let testResult {
                        Text(testResult)
                            .foregroundStyle(testResult.contains("ok") ? PulseTheme.green : PulseTheme.red)
                    }
                } footer: {
                    Text("The native app talks to your existing Pulse server over HTTPS using a Bearer session token.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(PulseTheme.bgA)
            .navigationTitle("API Base URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await appState.saveAPIBaseURL(draft)
                            dismiss()
                        }
                    }
                }
            }
            .onAppear { draft = appState.apiBaseURL }
        }
    }

    private func test() async {
        testing = true
        defer { testing = false }
        await appState.saveAPIBaseURL(draft)
        do {
            let ok = try await APIClient.shared.health()
            testResult = ok ? "Connection ok" : "Unexpected response"
            Haptics.success()
        } catch {
            testResult = error.localizedDescription
            Haptics.error()
        }
    }
}
