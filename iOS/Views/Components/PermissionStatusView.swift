//
//  PermissionStatusView.swift
//  Resonance
//
//  Reusable view displayed when a required permission has been denied.
//  Shows an icon, message, a primary action button, and a secondary
//  "Open Settings" button so the user can grant access.
//

import SwiftUI

// MARK: - Permission Status View

struct PermissionStatusView: View {
    let title: String
    let message: String
    let systemImage: String
    let actionTitle: String
    let onAction: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onAction) {
                Text(actionTitle)
            }
            .buttonStyle(.borderedProminent)

            Button("Open Settings") {
                openSettings()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    PermissionStatusView(
        title: "Music Access Required",
        message: "Resonance needs access to Apple Music to play songs and read your library.",
        systemImage: "music.note",
        actionTitle: "Grant Access",
        onAction: {}
    )
}
