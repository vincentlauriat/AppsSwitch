import SwiftUI
import AppsSwitchCore
import AppsSwitchUI

@main
struct AppsSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button("Vérifier les autorisations…") {
                appDelegate.showPermissionsOnboarding()
            }

            Divider()

            Button("Quitter AppsSwitch") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            MenuBarIconView()
        }

        Settings {
            SettingsView()
        }
    }
}

private struct SettingsView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("AppsSwitch \(version)")
                .font(.headline)
            Text("⌥Tab pour cycler entre toutes les fenêtres ouvertes, ⌥⇧Tab pour revenir en arrière.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(width: 340)
    }
}
