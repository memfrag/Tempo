import SwiftUI
import SwiftUIToolbox
import AttributionsUI
import Sparkle

@main
struct TempoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

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
            AboutCommand()
            CheckForUpdatesCommand(updater: updaterController.updater)
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

        AboutWindow(developedBy: "Martin Johannesson",
                    attributionsWindowID: AttributionsWindow.windowID)
        AttributionsWindow([
            ("SwiftUIToolkit", .bsd0Clause(year: "2026", holder: "Apparata AB")),
            ("Sparkle", .mit(year: "2006-2017", holder: "Andy Matuschak et al."))
        ], header: "The following software may be included in this product.")
    }
}
