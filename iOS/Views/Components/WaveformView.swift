//
//  WaveformView.swift
//  Resonance
//
//  A waveform visualization that doubles as a seek scrubber.
//  The played portion fills with the accent color; the unplayed
//  portion renders in muted vibrancy. Tap/drag to seek.
//

import SwiftUI

// MARK: - Waveform View

struct WaveformView: View {
    /// Normalized waveform amplitude samples (0.0 - 1.0), typically 100-200 points.
    let samples: [Float]

    /// Playback progress (0.0 - 1.0).
    @Binding var progress: Double

    /// Whether the user is actively scrubbing.
    @Binding var isScrubbing: Bool

    /// Accent color for the played portion.
    var accentColor: Color = .blue

    /// Called when the user finishes scrubbing.
    var onSeekComplete: ((Double) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scrubProgress = 0.0

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let barCount = samples.count
            let barWidth = barCount > 0 ? max(1, width / CGFloat(barCount) - 1) : CGFloat(1)
            let spacing = width / CGFloat(max(barCount, 1))

            Canvas { context, size in
                let activeProgress = isScrubbing ? scrubProgress : progress

                for (index, sample) in samples.enumerated() {
                    let x = spacing * CGFloat(index)
                    let amplitude = CGFloat(max(0.05, min(1.0, sample)))
                    let barHeight = amplitude * height * 0.8
                    let y = (height - barHeight) / 2

                    let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                    let isPlayed = CGFloat(index) / CGFloat(barCount) <= CGFloat(activeProgress)

                    let color: Color = isPlayed ? accentColor : .gray.opacity(0.3)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(color)
                    )
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isScrubbing = true
                        let newProgress = max(0, min(1, Double(value.location.x / width)))
                        scrubProgress = newProgress
                    }
                    .onEnded { value in
                        let finalProgress = max(0, min(1, Double(value.location.x / width)))
                        scrubProgress = finalProgress
                        isScrubbing = false
                        onSeekComplete?(finalProgress)
                    }
            )
        }
        .frame(height: 40)
        .accessibilityLabel("Waveform seek bar")
        .accessibilityValue("\(Int(progress * 100))% played")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                let newProgress = min(1.0, progress + 0.05)
                progress = newProgress
                onSeekComplete?(newProgress)
            case .decrement:
                let newProgress = max(0.0, progress - 0.05)
                progress = newProgress
                onSeekComplete?(newProgress)
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Waveform Data Generator

/// Generates placeholder waveform data from song metadata.
/// In production, this would use AVAudioEngine to extract real amplitude data.
enum WaveformDataGenerator {
    /// Generates synthetic waveform data based on song energy and BPM.
    /// Produces visually plausible waveforms without actual audio analysis.
    static func generate(energy: Double, bpm: Double, sampleCount: Int = 150) -> [Float] {
        var samples: [Float] = []
        let baseAmplitude = Float(max(0.2, min(0.9, energy)))

        for i in 0..<sampleCount {
            let position = Float(i) / Float(sampleCount)

            // Create a pseudo-waveform shape with beats
            let beatPhase = sin(Float(i) * Float(bpm) / 60.0 * .pi * 2.0 / Float(sampleCount) * 10.0)
            let envelope = 0.5 + 0.5 * sin(position * .pi)  // Fade in/out

            // Add some randomness for visual interest (deterministic based on index)
            let noise = Float(((i * 7 + 13) % 17)) / 17.0 * 0.3

            let amplitude = baseAmplitude * envelope * (0.7 + 0.3 * abs(beatPhase)) + noise * 0.1
            samples.append(min(1.0, max(0.05, amplitude)))
        }

        return samples
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        WaveformView(
            samples: WaveformDataGenerator.generate(energy: 0.7, bpm: 128),
            progress: .constant(0.4),
            isScrubbing: .constant(false)
        )
        .padding(.horizontal)

        WaveformView(
            samples: WaveformDataGenerator.generate(energy: 0.3, bpm: 70),
            progress: .constant(0.6),
            isScrubbing: .constant(false),
            accentColor: .purple
        )
        .padding(.horizontal)
    }
}
