//
//  VinylSFXPlayer.swift
//  Resonance
//
//  Sound effects manager for vinyl record interactions.
//  Plays needle drop scratch, ambient crackle loop, and coordinates
//  haptic feedback. Uses AVAudioPlayer with .mixWithOthers to coexist
//  with MusicKit playback.
//

import AVFoundation
import UIKit

final class VinylSFXPlayer {
    // MARK: - Singleton

    static let shared = VinylSFXPlayer()

    // MARK: - Properties

    private var needleDropPlayer: AVAudioPlayer?
    private var cracklePlayer: AVAudioPlayer?

    /// Whether ambient crackle is currently playing
    private(set) var isCracklePlaying = false

    /// User preference for crackle sound (persisted via UserDefaults)
    var isCrackleEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "vinylCrackleEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "vinylCrackleEnabled") }
    }

    /// User preference for needle drop sound
    var isNeedleDropEnabled: Bool {
        get {
            // Default to true if key hasn't been set
            if UserDefaults.standard.object(forKey: "vinylNeedleDropEnabled") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "vinylNeedleDropEnabled")
        }
        set { UserDefaults.standard.set(newValue, forKey: "vinylNeedleDropEnabled") }
    }

    // Haptic generators (pre-warmed for low latency)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let selectionFeedback = UISelectionFeedbackGenerator()

    // MARK: - Init

    private init() {
        configureAudioSession()
        prepareAudioPlayers()
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: .mixWithOthers)
            try session.setActive(true)
        } catch {
            // Non-fatal: SFX won't play but app continues
            print("[VinylSFX] Audio session config failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Player Preparation

    private func prepareAudioPlayers() {
        // Needle drop
        if let url = Bundle.main.url(forResource: "needle_drop", withExtension: "wav") {
            do {
                needleDropPlayer = try AVAudioPlayer(contentsOf: url)
                needleDropPlayer?.prepareToPlay()
                needleDropPlayer?.volume = 0.4
            } catch {
                print("[VinylSFX] needle_drop.wav load failed: \(error.localizedDescription)")
            }
        }

        // Vinyl crackle loop
        if let url = Bundle.main.url(forResource: "vinyl_crackle", withExtension: "wav") {
            do {
                cracklePlayer = try AVAudioPlayer(contentsOf: url)
                cracklePlayer?.numberOfLoops = -1 // Infinite loop
                cracklePlayer?.volume = VinylConstants.crackleVolume
                cracklePlayer?.prepareToPlay()
            } catch {
                print("[VinylSFX] vinyl_crackle.wav load failed: \(error.localizedDescription)")
            }
        }
    }

    private static let normalVolume: Float = 0.4
    private static let liftVolume: Float = 0.25

    // MARK: - Needle Drop

    /// Plays the needle drop scratch sound with a medium impact haptic.
    func playNeedleDrop() {
        guard isNeedleDropEnabled else { return }

        // Haptic
        mediumImpact.prepare()
        mediumImpact.impactOccurred()

        // Always reset to normal volume before playing
        needleDropPlayer?.volume = Self.normalVolume
        needleDropPlayer?.currentTime = 0
        needleDropPlayer?.play()
    }

    /// Plays a lighter needle lift sound with a light impact haptic.
    func playNeedleLift() {
        guard isNeedleDropEnabled else { return }

        // Haptic
        lightImpact.prepare()
        lightImpact.impactOccurred()

        // Play at reduced volume; next playNeedleDrop() resets volume before playing
        needleDropPlayer?.volume = Self.liftVolume
        needleDropPlayer?.currentTime = 0
        needleDropPlayer?.play()
    }

    // MARK: - Crackle

    /// Starts the ambient vinyl crackle loop.
    func startCrackle() {
        guard isCrackleEnabled, !isCracklePlaying else { return }
        cracklePlayer?.play()
        isCracklePlaying = true
    }

    /// Stops the ambient vinyl crackle loop.
    func stopCrackle() {
        cracklePlayer?.pause()
        isCracklePlaying = false
    }

    // MARK: - Haptics

    /// Fire a selection haptic (used when starting a seek drag).
    func fireSelectionHaptic() {
        selectionFeedback.prepare()
        selectionFeedback.selectionChanged()
    }

    /// Fire a light impact haptic (used for skip/previous).
    func fireLightImpact() {
        lightImpact.prepare()
        lightImpact.impactOccurred()
    }

    /// Pre-warm haptic generators before an expected interaction.
    func prepareHaptics() {
        mediumImpact.prepare()
        lightImpact.prepare()
        selectionFeedback.prepare()
    }
}
