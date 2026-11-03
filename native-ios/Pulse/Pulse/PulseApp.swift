import SwiftUI

@main
struct PulseApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .tint(PulseTheme.purple)
                .onChange(of: scenePhase) { _, phase in
                    appState.handleScenePhase(phase)
                }
        }
    }
}
