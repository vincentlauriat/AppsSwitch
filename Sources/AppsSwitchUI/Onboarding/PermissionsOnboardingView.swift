import SwiftUI
import AppsSwitchCore

public struct PermissionsOnboardingView: View {
    private var permissionsManager: PermissionsManager

    public init(permissionsManager: PermissionsManager) {
        self.permissionsManager = permissionsManager
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("AppsSwitch a besoin de deux autorisations système")
                .font(.headline)

            row(
                title: "Accessibilité",
                detail: "Nécessaire pour détecter le raccourci ⌥Tab et activer la fenêtre choisie.",
                granted: permissionsManager.status.accessibilityGranted,
                requestTitle: "Demander l'autorisation",
                request: permissionsManager.requestAccessibility,
                openSettings: { permissionsManager.openSystemSettings(.accessibility) }
            )

            row(
                title: "Enregistrement d'écran",
                detail: "Nécessaire pour afficher une miniature en direct de chaque fenêtre. Une fois l'autorisation accordée, quittez et relancez AppsSwitch pour qu'elle soit prise en compte.",
                granted: permissionsManager.status.screenRecordingGranted,
                requestTitle: "Demander l'autorisation",
                request: permissionsManager.requestScreenRecording,
                openSettings: { permissionsManager.openSystemSettings(.screenRecording) }
            )
        }
        .padding(24)
        .frame(width: 420)
    }

    @ViewBuilder
    private func row(
        title: String,
        detail: String,
        granted: Bool,
        requestTitle: String,
        request: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(granted ? .green : .orange)
                Text(title).font(.subheadline.bold())
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
            if !granted {
                HStack {
                    Button(requestTitle, action: request)
                    Button("Ouvrir Réglages Système…", action: openSettings)
                }
            }
        }
    }
}
