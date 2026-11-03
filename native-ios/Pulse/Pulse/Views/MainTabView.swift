import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch appState.selectedTab {
                case .home:
                    HomeView()
                case .insights:
                    InsightsView()
                case .calendar:
                    CalendarView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Keep settings root when leaving the tab, matching mobile reset feel when re-entering via nav.
            .onChange(of: appState.selectedTab) { _, tab in
                if tab != .settings {
                    appState.settingsView = .root
                }
            }

            PulseTabBar()
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $appState.showQuickAdd) {
            QuickAddSheet()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $appState.showSearch) {
            SearchView()
                .environmentObject(appState)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 72)
        }
    }
}

struct PulseTabBar: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            ForEach([PulseTab.home, .insights], id: \.self) { tab in
                tabButton(tab)
            }

            Button {
                Haptics.medium()
                appState.quickAddDraft = TransactionDraft()
                appState.applyCategorySuggestion()
                appState.showQuickAdd = true
            } label: {
                ZStack {
                    Circle()
                        .fill(PulseTheme.primaryGradient)
                        .frame(width: 58, height: 58)
                        .shadow(color: PulseTheme.pink.opacity(0.35), radius: 12, y: 4)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(y: -14)
            }
            .accessibilityLabel("Add transaction")

            ForEach([PulseTab.calendar, .settings], id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 22, topTrailing: 22), style: .continuous)
                .fill(Color(red: 12 / 255, green: 10 / 255, blue: 24 / 255).opacity(0.96))
                .overlay(alignment: .top) {
                    Rectangle().fill(PulseTheme.line.opacity(0.7)).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(_ tab: PulseTab) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundStyle(appState.selectedTab == tab ? PulseTheme.pink : PulseTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
