import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isBootstrapping {
                SplashView()
            } else if !appState.isAuthenticated {
                LoginView()
            } else if appState.isLocked {
                BiometricLockView()
            } else if appState.needsOnboarding {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.isAuthenticated)
        .animation(.easeInOut(duration: 0.25), value: appState.isLocked)
        .animation(.easeInOut(duration: 0.25), value: appState.needsOnboarding)
        .alert("Something went wrong", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
    }
}

struct SplashView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            PulseBackground()
            VStack(spacing: 18) {
                Image("PulseLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .scaleEffect(pulse ? 1.05 : 0.95)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
                Text("Pulse")
                    .font(PulseTheme.displayFont)
                    .foregroundStyle(PulseTheme.textMain)
                Text("Finding your rhythm")
                    .foregroundStyle(PulseTheme.textMuted)
                ProgressView()
                    .tint(PulseTheme.pink)
                    .padding(.top, 8)
            }
        }
        .onAppear { pulse = true }
    }
}

struct BiometricLockView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            PulseBackground()
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(PulseTheme.pink)
                Text("Pulse is locked")
                    .font(PulseTheme.titleFont)
                Text("Use Face ID or Touch ID to continue.")
                    .foregroundStyle(PulseTheme.textMuted)
                    .multilineTextAlignment(.center)
                Button("Unlock") {
                    Task { await appState.unlockWithBiometrics() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)

                Button("Sign out") {
                    Task { await appState.logout() }
                }
                .foregroundStyle(PulseTheme.textMuted)
            }
            .padding()
        }
        .task { await appState.unlockWithBiometrics() }
    }
}
