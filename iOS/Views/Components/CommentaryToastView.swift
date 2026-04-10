//
//  CommentaryToastView.swift
//  Resonance
//
//  Floating toast notification for AI DJ commentary at track transitions.
//  Appears at the top of NowPlayingView, below the navigation bar,
//  with auto-dismiss after 5 seconds and swipe-up-to-dismiss.
//
//  Part of E8: AI DJ Commentary via Foundation Models.
//

import SwiftUI
#if canImport(Accessibility)
import Accessibility
#endif

// MARK: - Commentary Toast View

/// A floating glass toast that displays brief DJ commentary during track transitions.
///
/// Positioned at the top of NowPlayingView, it slides in from above with a spring
/// animation, auto-dismisses after 5 seconds, and supports swipe-up-to-dismiss.
/// Uses glass background with subtle accent border, matching Resonance design language.
struct CommentaryToastView: View {

    // MARK: - Properties

    /// The commentary text to display (1-2 sentences).
    let text: String

    /// Called when the toast should be dismissed (tap or swipe up).
    var onDismiss: () -> Void

    /// Accessibility: reduce motion preference.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Drag offset for swipe-to-dismiss gesture.
    @State private var dragOffset: CGFloat = 0

    /// Auto-dismiss timer task.
    @State private var autoDismissTask: Task<Void, Never>?

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ResonanceColors.accent)
                .accessibilityHidden(true)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                dismissToast()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss commentary")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            ResonanceColors.accent.opacity(0.25),
                            lineWidth: 0.5
                        )
                )
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    // Only allow upward drag (negative translation)
                    if value.translation.height < 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height < -30 {
                        // Swipe up threshold met -- dismiss
                        dismissToast()
                    } else {
                        // Snap back
                        withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .transition(
            reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("DJ Commentary: \(text)")
        .accessibilityAddTraits(.isStaticText)
        .accessibilityAction(.escape) {
            dismissToast()
        }
        .onAppear {
            announceForAccessibility()
            startAutoDismissTimer()
        }
        .onDisappear {
            autoDismissTask?.cancel()
        }
    }

    // MARK: - Actions

    /// Dismisses the toast with animation.
    private func dismissToast() {
        autoDismissTask?.cancel()
        onDismiss()
    }

    /// Starts an auto-dismiss timer. Extended to 15 seconds when VoiceOver is active.
    private func startAutoDismissTimer() {
        autoDismissTask?.cancel()
        autoDismissTask = Task { @MainActor in
            let timeout: UInt64 = UIAccessibility.isVoiceOverRunning ? 15_000_000_000 : 5_000_000_000
            try? await Task.sleep(nanoseconds: timeout)
            guard !Task.isCancelled else { return }
            onDismiss()
        }
    }

    /// Announces the commentary for VoiceOver users.
    private func announceForAccessibility() {
        #if canImport(Accessibility)
        if #available(iOS 17.0, *) {
            AccessibilityNotification.Announcement("DJ says: \(text)").post()
        }
        #endif
    }
}

// MARK: - Preview

#Preview("Commentary Toast - Short") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            CommentaryToastView(
                text: "Picking up the tempo -- this one should lift the energy.",
                onDismiss: {}
            )
            .padding(.horizontal, 16)
            .padding(.top, 60)

            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Commentary Toast - Long") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            CommentaryToastView(
                text: "Your stress has eased off nicely -- \"Blue in Green\" keeps that calm momentum going as you settle into relaxation.",
                onDismiss: {}
            )
            .padding(.horizontal, 16)
            .padding(.top, 60)

            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Commentary Toast - Milestone") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            CommentaryToastView(
                text: "25 tracks deep. \"Midnight City\" keeps the session rolling.",
                onDismiss: {}
            )
            .padding(.horizontal, 16)
            .padding(.top, 60)

            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}
