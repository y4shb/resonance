//
//  AudioRouteControls.swift
//  Resonance
//
//  UIViewRepresentable wrappers for system volume and AirPlay controls.
//  Used by NowPlayingView to provide native volume slider and route picker.
//

import SwiftUI
import MediaPlayer
import AVKit

// MARK: - System Volume Slider (MPVolumeView)

/// Wraps MPVolumeView to provide a native system volume slider.
/// Note: Do NOT call setVolumeThumbImage(UIImage(), ...) — passing an empty
/// UIImage removes the thumb entirely, making the slider un-draggable.
/// The default system thumb inherits tintColor and is fully accessible.
struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsRouteButton = false  // Route picker is separate (AirPlayButton)
        volumeView.tintColor = UIColor(red: 0.35, green: 0.55, blue: 1.0, alpha: 1.0)
        return volumeView
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

// MARK: - AirPlay Button (AVRoutePickerView)

/// Wraps AVRoutePickerView to provide a native AirPlay route picker button.
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView(frame: .zero)
        picker.tintColor = UIColor(ResonanceColors.accent)
        picker.activeTintColor = UIColor(ResonanceColors.accent)
        picker.prioritizesVideoDevices = false
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
