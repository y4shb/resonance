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
struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsRouteButton = false
        volumeView.setVolumeThumbImage(UIImage(), for: .normal)
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
