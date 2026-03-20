//
//  ShakeDetector.swift
//  Resonance
//
//  Detects iPhone shake gestures and exposes them as a SwiftUI view modifier.
//  Used by Sonic Bookmark to let users bookmark moments by shaking their phone.
//

#if os(iOS)

import UIKit
import SwiftUI

// MARK: - Shake Notification

extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name("deviceDidShakeNotification")
}

// MARK: - UIWindow Override

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

// MARK: - SwiftUI View Modifier

struct DeviceShakeViewModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(
                NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)
            ) { _ in
                action()
            }
    }
}

extension View {
    /// Performs an action when the device is shaken.
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(DeviceShakeViewModifier(action: action))
    }
}

#endif
