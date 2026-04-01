import SwiftUI

@main
struct TempoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAuthenticated {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
            .environment(appState)
            .task {
                await appState.restoreSession()
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Entry") {
                    // Focus quick start bar
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        MenuBarExtra("Tempo", systemImage: "clock") {
            MenuBarPopover()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)
    }
}
