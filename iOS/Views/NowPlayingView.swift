//
//  NowPlayingView.swift
//  Resonance
//
//  Displays the currently playing track with album artwork, song info,
//  playback progress, and transport controls.
//
//  P2-20: Dark Mode Palette Refinement — uses ResonanceColors for backgrounds
//  P2-21: Album Art Ambient Glow — adds radial glow behind artwork
//

import SwiftUI
import MusicKit

// MARK: - Now Playing View

struct NowPlayingView: View {
    // MARK: - Properties

    @Bindable var viewModel: NowPlayingViewModel
    @ObservedObject var stateEngine: StateEngine

    /// Optional namespace for matchedGeometryEffect transition from landing screen
    var heroNamespace: Namespace.ID?

    /// Callback to switch to the playlists tab from the empty state
    var onBrowsePlaylists: (() -> Void)?

    // Accessibility
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Dark mode detection (P2-20)
    @Environment(\.colorScheme) private var colorScheme

    // Track whether user is actively scrubbing the slider
    @State private var isScrubbing = false
    @State private var scrubProgress = 0.0
    @State private var showMoodInput = false
    @State private var isExplanationExpanded = false

    // Dominant color for ambient glow (P2-21)
    @State private var dominantGlowColor: Color?

    // Haptic feedback triggers for transport controls
    @State private var skipTrigger = 0
    @State private var previousTrigger = 0
    @State private var bookmarkTrigger = 0
    @State private var showQueue = false
    @State private var showExplanation = false
    @State private var showTuning = false
    @State private var animatePulse = false
    @State private var playPauseTrigger = 0

    // E3: Natural language request input
    @State private var isNLInputExpanded = false
    @State private var nlRequestText = ""
    @FocusState private var isNLFieldFocused: Bool

    /// Enlarged artwork size for the decluttered Now Playing layout
    private let artworkDisplaySize: CGFloat = 340

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.activePlaylistName == nil && viewModel.currentSong == .placeholder {
                    emptyStateView
                } else {
                    mainPlayerContent
                }
            }
            .navigationTitle("Resonance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.requestAISelection()
                    } label: {
                        Image(systemName: "wand.and.stars")
                    }
                    .disabled(viewModel.activePlaylistName == nil)
                    .accessibilityLabel("AI Select Next Song")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // E3: Natural language request button
                        Button {
                            withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.8)) {
                                isNLInputExpanded.toggle()
                                if isNLInputExpanded {
                                    isNLFieldFocused = true
                                } else {
                                    isNLFieldFocused = false
                                    nlRequestText = ""
                                }
                            }
                        } label: {
                            Image(systemName: isNLInputExpanded ? "xmark.circle.fill" : "text.bubble")
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .accessibilityLabel(isNLInputExpanded ? "Close text request" : "Make a request")
                        .accessibilityHint("Ask the DJ for something specific")

                        Button { showTuning = true } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .accessibilityLabel("DJ Tuning")
                        .accessibilityHint("Adjust exploration bias and volume")

                        Button {
                            bookmarkTrigger += 1
                            viewModel.createBookmark(source: .iphoneButton)
                        } label: {
                            Image(systemName: "bookmark.fill")
                        }
                        .disabled(viewModel.currentSong == .placeholder)
                        .accessibilityLabel("Bookmark this moment")

                        Button {
                            showMoodInput = true
                        } label: {
                            Image(systemName: "face.smiling")
                        }
                        .accessibilityLabel("Set Mood")
                    }
                }
            }
            .sheet(isPresented: $showMoodInput) {
                MoodInputView(stateEngine: stateEngine)
            }
            .sheet(isPresented: $showQueue) {
                QueueView(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showExplanation) {
                explanationSheet
            }
            .sheet(isPresented: $showTuning) {
                tuningSheet
            }
            .alert("Playback Error", isPresented: showErrorBinding) {
                Button("Retry") {
                    viewModel.errorMessage = nil
                    viewModel.togglePlayPause()
                }
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onShake {
                guard viewModel.currentSong != .placeholder else { return }
                bookmarkTrigger += 1
                viewModel.createBookmark(source: .iphoneShake)
            }
            .sensoryFeedback(.success, trigger: bookmarkTrigger)
        }
    }

    // MARK: - Error Binding

    private var showErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    // MARK: - Artwork View

    /// Approximate heart rate derived from arousal (maps 0-1 to 50-130 BPM range)
    private var approximateHeartRate: Double {
        stateEngine.currentState.arousal * 80 + 50
    }

    private var artworkView: some View {
        ZStack {
            // Heart pulse ring behind artwork
            HeartPulseRing(
                heartRate: approximateHeartRate,
                musicBPM: viewModel.currentSongBPM,
                accentColor: viewModel.artworkAccentColor ?? ResonanceColors.accent,
                reduceMotion: reduceMotion,
                isTransitioning: viewModel.isTransitioningTrack
            )
            .frame(
                width: artworkDisplaySize + 24,
                height: artworkDisplaySize + 24
            )

            // Artwork
            Group {
                if let artwork = viewModel.currentSong.artwork {
                    ArtworkImage(artwork, width: artworkDisplaySize)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
                } else {
                    // Placeholder artwork
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .frame(
                            width: artworkDisplaySize,
                            height: artworkDisplaySize
                        )
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.7))
                        )
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
            }
            .modifier(HeroArtworkModifier(namespace: heroNamespace))
        }
        .accessibilityLabel("Album art: \(viewModel.currentSong.title) by \(viewModel.currentSong.artistName)")
    }

    // MARK: - Song Info View

    private var songInfoView: some View {
        VStack(spacing: 6) {
            Text(viewModel.currentSong.title)
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .multilineTextAlignment(.center)

            Text(viewModel.currentSong.artistName)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Progress View

    private var progressView: some View {
        VStack(spacing: 4) {
            Slider(
                value: isScrubbing
                    ? $scrubProgress
                    : Binding(
                        get: { viewModel.playbackProgress },
                        set: { viewModel.playbackProgress = $0 }
                    ),
                in: 0...1,
                onEditingChanged: { editing in
                    isScrubbing = editing
                    if editing {
                        scrubProgress = viewModel.playbackProgress
                        viewModel.seekStarted()
                    } else {
                        viewModel.seek(to: scrubProgress)
                    }
                }
            )
            .tint(ResonanceColors.accent)
            .accessibilityLabel("Playback progress")
            .accessibilityValue("\(viewModel.currentTime.formattedMinutesSeconds) of \(viewModel.duration.formattedMinutesSeconds)")

            HStack {
                Text((isScrubbing ? scrubProgress * viewModel.duration : viewModel.currentTime)
                    .formattedMinutesSeconds)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

                Spacer()

                Text(viewModel.duration.formattedMinutesSeconds)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack(spacing: 40) {
            Button(action: {
                previousTrigger += 1
                viewModel.previous()
            }) {
                Image(systemName: "backward.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .glassEffect(.regular.interactive())
            .accessibilityLabel("Previous track")
            .sensoryFeedback(.impact(weight: .light), trigger: previousTrigger)

            Button(action: {
                playPauseTrigger += 1
                viewModel.togglePlayPause()
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(ResonanceColors.accent)
                    .frame(width: 64, height: 64)
                    .contentShape(Circle())
            }
            .glassEffect(.regular.interactive())
            .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
            .sensoryFeedback(.impact(weight: .medium), trigger: playPauseTrigger)

            Button(action: {
                skipTrigger += 1
                viewModel.skip()
            }) {
                Image(systemName: "forward.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .glassEffect(.regular.interactive())
            .accessibilityLabel("Skip to next track")
            .sensoryFeedback(.impact(weight: .light), trigger: skipTrigger)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .glassEffect(.regular)
    }

    // MARK: - Exploration Bias Control ("Surprise Me" / "Stay in the Zone")

    /// Slider state for live dragging without persisting on every frame
    @State private var explorationSliderValue: Double = UserPreferences.load().explorationBias
    @State private var isExplorationSliderEditing = false

    private var explorationBiasControl: some View {
        VStack(spacing: 6) {
            // Mode label with icon
            HStack(spacing: 6) {
                Image(systemName: viewModel.explorationBiasIcon)
                    .font(.caption)
                    .foregroundStyle(explorationAccentColor)
                    .contentTransition(.symbolEffect(.replace))

                Text(viewModel.explorationBiasLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(explorationAccentColor)

                Spacer()

                // Queue button integrated into this row
                Button(action: { showQueue = true }) {
                    Image(systemName: "list.bullet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Up Next")
            }

            // Slider with endpoint labels
            HStack(spacing: 10) {
                Image(systemName: "target")
                    .font(.caption2)
                    .foregroundStyle(explorationSliderValue < 0.5 ? ResonanceColors.accent : Color.secondary.opacity(0.6))

                Slider(
                    value: $explorationSliderValue,
                    in: 0...1,
                    step: 0.05,
                    onEditingChanged: { editing in
                        isExplorationSliderEditing = editing
                        if !editing {
                            viewModel.setExplorationBias(explorationSliderValue)
                        }
                    }
                )
                .tint(explorationAccentColor)
                .onChange(of: explorationSliderValue) {
                    // Update the label in real time while dragging
                    if isExplorationSliderEditing {
                        viewModel.explorationBias = explorationSliderValue
                    }
                }

                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(explorationSliderValue > 0.5 ? ResonanceColors.accent : Color.secondary.opacity(0.6))
            }

            // Endpoint text labels
            HStack {
                Text("Stay in the Zone")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("Surprise Me")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AI exploration bias")
        .accessibilityValue(viewModel.explorationBiasLabel)
        .accessibilityHint("Slide left for familiar songs, right for discovery")
    }

    /// Accent color for the exploration slider, shifting from blue (zone) to purple (surprise)
    private var explorationAccentColor: Color {
        // Interpolate from accent (zone) to purple (surprise)
        let bias = explorationSliderValue
        if bias < 0.5 {
            return ResonanceColors.accent
        } else {
            return .purple.opacity(0.7 + bias * 0.3)
        }
    }

    // MARK: - Main Player Content

    @ViewBuilder
    private var mainPlayerContent: some View {
        ZStack {
            ResonanceColors.adaptiveBackground(for: colorScheme)
                .ignoresSafeArea()

            if let glowColor = dominantGlowColor {
                AmbientGlowView(
                    color: ResonanceColors.darkModeAdjusted(glowColor, for: colorScheme),
                    reduceMotion: reduceMotion
                )
            }

            mainPlayerVStack
                .padding(.horizontal, 20)
                .background(artworkBackgroundGradient)
        }
        .overlay(alignment: .top) {
            commentaryOverlay
        }
        .onChange(of: viewModel.artworkAccentColor) {
            updateDominantGlowColor()
        }
        .onAppear {
            updateDominantGlowColor()
            explorationSliderValue = viewModel.explorationBias
        }
    }

    @ViewBuilder
    private var mainPlayerVStack: some View {
        VStack(spacing: 0) {
            statusAndInputSection
            Spacer(minLength: 4)
            artworkSection
                .padding(.bottom, 24)
            songInfoView
                .padding(.bottom, 12)
            progressView
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            transportControls
                .padding(.bottom, 16)
            bottomActionRow
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            Spacer(minLength: 4)
        }
    }

    @ViewBuilder
    private var statusAndInputSection: some View {
        HStack(spacing: 0) {
            StatusPillView(
                stateEngine: stateEngine,
                activePlaylistName: viewModel.activePlaylistName
            )
            if viewModel.weatherInfluenceEnabled {
                Image(systemName: viewModel.currentWeatherSymbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 6)
                    .transition(.opacity)
                    .accessibilityLabel("Weather: \(viewModel.currentWeatherDescription)")
            }
        }
        .padding(.top, 8)

        if isNLInputExpanded {
            nlInputBar
        }

        if viewModel.isADHDFocusActive {
            FocusStreakView(
                streaks: viewModel.focusStreaks,
                currentStreak: viewModel.currentFocusStreak,
                pomodoroPhase: viewModel.pomodoroTimer.phase,
                pomodoroProgress: viewModel.pomodoroTimer.progress,
                totalFocusMinutes: viewModel.totalFocusMinutes
            )
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .transition(.opacity)
            .accessibilityLabel("Focus streak: \(Int(viewModel.totalFocusMinutes)) minutes")
        }
    }

    @ViewBuilder
    private var artworkSection: some View {
        ZStack {
            artworkView
            if viewModel.isLoadingAISelection {
                TimedSkeletonView(message: "AI is analyzing your state and library...") {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .frame(width: artworkDisplaySize, height: artworkDisplaySize)
                        .overlay(
                            VStack(spacing: 16) {
                                SkeletonShape(width: 120, height: 14, cornerRadius: 4)
                                SkeletonShape(width: 80, height: 10, cornerRadius: 3)
                            }
                            .shimmer()
                        )
                }
                .accessibilityLabel("Loading next song")
            }
        }
    }

    @ViewBuilder
    private var commentaryOverlay: some View {
        if let commentary = viewModel.commentaryMessage {
            CommentaryToastView(text: commentary, onDismiss: {
                viewModel.dismissCommentary()
            })
            .padding(.top, 60)
            .padding(.horizontal, 20)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(
                reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.8),
                value: viewModel.commentaryMessage
            )
            .accessibilityLabel("DJ Commentary: \(commentary)")
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    // MARK: - Natural Language Input Bar (E3)

    private var nlInputBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.caption)
                .foregroundStyle(ResonanceColors.accent)

            TextField("Ask the DJ anything...", text: $nlRequestText)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .focused($isNLFieldFocused)
                .submitLabel(.send)
                .onSubmit {
                    submitAndCloseNL()
                }

            if !nlRequestText.isEmpty {
                Button {
                    submitAndCloseNL()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(ResonanceColors.accent)
                }
                .accessibilityLabel("Send request")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Natural language request field")
    }

    private func submitAndCloseNL() {
        let text = nlRequestText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        viewModel.submitNLRequest(text)
        nlRequestText = ""
        let anim: Animation? = reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.8)
        withAnimation(anim) {
            isNLInputExpanded = false
        }
    }

    // MARK: - Standalone Queue Button

    private var queueButton: some View {
        EmptyView()  // Queue button is now embedded in explorationBiasControl header
    }

    // MARK: - Volume & Route Controls

    private var volumeAndRouteControls: some View {
        HStack(spacing: 16) {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            SystemVolumeSlider()
                .frame(height: 36)
                .tint(ResonanceColors.accent)

            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            AirPlayButton()
                .frame(width: 44, height: 44)
        }
    }

    // MARK: - Explanation Bar (Glass Card)

    private var explanationBar: some View {
        Group {
            if let explanation = viewModel.currentExplanation {
                VStack(spacing: 0) {
                    Button(action: {
                        withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.75)) {
                            isExplanationExpanded.toggle()
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Collapsed header (always visible)
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "wand.and.stars")
                                    .font(.subheadline)
                                    .foregroundStyle(ResonanceColors.accent)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Why this song")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(ResonanceColors.accent)
                                        .textCase(.uppercase)
                                        .tracking(0.5)

                                    Text(explanation.full)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary.opacity(0.85))
                                        .lineLimit(isExplanationExpanded ? nil : 2)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer(minLength: 4)

                                Image(systemName: isExplanationExpanded ? "chevron.up" : "chevron.down")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                    .padding(.top, 4)
                            }

                            // Expanded factor breakdown with horizontal bar charts
                            if isExplanationExpanded {
                                expandedFactorsView(factors: explanation.factors)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .glassEffect(.regular)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(explanationAccessibilityLabel(explanation))
                    .accessibilityHint(isExplanationExpanded ? "Tap to collapse" : "Tap to see why this song was chosen")

                    // Thumbs up/down feedback buttons (only when expanded)
                    if isExplanationExpanded {
                        aiFeedbackButtons
                    }
                }
            }
        }
    }

    /// Shows the top 3-4 factors as horizontal bar charts when expanded.
    private func expandedFactorsView(factors: [ExplanationFactor]) -> some View {
        let topFactors = Array(factors.prefix(4))

        return VStack(alignment: .leading, spacing: 10) {
            Divider()
                .padding(.vertical, 8)

            if topFactors.isEmpty {
                Text("Selected based on your current state")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(topFactors) { factor in
                    factorRow(factor: factor, maxContribution: topFactors.first?.contribution ?? 1.0)
                }
            }
        }
    }

    /// A single factor row with label, horizontal bar, and percentage.
    private func factorRow(factor: ExplanationFactor, maxContribution: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(factor.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary.opacity(0.9))

                Spacer()

                Text("\(Int(factor.contribution * 100))%")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.primary.opacity(0.08))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [ResonanceColors.accent.opacity(0.7), ResonanceColors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: factorBarWidth(
                                contribution: factor.contribution,
                                maxContribution: maxContribution,
                                availableWidth: geometry.size.width
                            ),
                            height: 6
                        )
                        .animation(
                            reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.7).delay(0.05),
                            value: isExplanationExpanded
                        )
                }
            }
            .frame(height: 6)

            Text(factor.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(factor.name): \(Int(factor.contribution * 100)) percent. \(factor.description)")
    }

    /// Bar width normalized against the top factor.
    private func factorBarWidth(contribution: Double, maxContribution: Double, availableWidth: CGFloat) -> CGFloat {
        guard maxContribution > 0 else { return 0 }
        let normalized = contribution / maxContribution
        return max(CGFloat(normalized) * availableWidth, 4)
    }

    /// Builds accessibility label for the explanation card.
    private func explanationAccessibilityLabel(_ explanation: SongExplanation) -> String {
        var label = "AI explanation: \(explanation.full)"
        if isExplanationExpanded && !explanation.factors.isEmpty {
            let factorDescriptions = explanation.factors.prefix(4).map { factor in
                "\(factor.name): \(Int(factor.contribution * 100)) percent"
            }.joined(separator: ", ")
            label += ". Factors: \(factorDescriptions)"
        }
        return label
    }

    // MARK: - AI Feedback Buttons

    @State private var feedbackTrigger = 0

    private var aiFeedbackButtons: some View {
        HStack(spacing: 24) {
            Spacer()

            Button {
                feedbackTrigger += 1
                viewModel.submitAIFeedback(isPositive: false)
            } label: {
                Image(systemName: viewModel.currentSongFeedback == false
                    ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.body)
                    .foregroundStyle(viewModel.currentSongFeedback == false
                        ? .red : .secondary)
                    .frame(width: 44, height: 36)
                    .contentShape(Rectangle())
            }
            .disabled(viewModel.currentSongFeedback != nil)
            .accessibilityLabel("Thumbs down")
            .accessibilityHint("This song doesn't fit your current mood")

            Button {
                feedbackTrigger += 1
                viewModel.submitAIFeedback(isPositive: true)
            } label: {
                Image(systemName: viewModel.currentSongFeedback == true
                    ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.body)
                    .foregroundStyle(viewModel.currentSongFeedback == true
                        ? ResonanceColors.accent : .secondary)
                    .frame(width: 44, height: 36)
                    .contentShape(Rectangle())
            }
            .disabled(viewModel.currentSongFeedback != nil)
            .accessibilityLabel("Thumbs up")
            .accessibilityHint("This song fits your current mood perfectly")

            Spacer()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackTrigger)
        .padding(.top, 4)
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }

    // MARK: - HRV Zone Indicator

    private var hrvZoneBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(hrvZoneColor)
                .frame(width: 8, height: 8)
                .shadow(color: hrvZoneColor.opacity(0.6), radius: 4)

            Text(hrvZoneName)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Heart rate variability zone: \(hrvZoneName)")
    }

    /// Returns the HRV zone color based on current stress level
    private var hrvZoneColor: Color {
        let stress = stateEngine.currentState.stress
        if stress < 0.35 {
            return .green      // Recovered / relaxed
        } else if stress < 0.65 {
            return .yellow     // Normal / active
        } else {
            return .red        // Stressed / elevated
        }
    }

    /// Returns the HRV zone name based on current stress level
    private var hrvZoneName: String {
        let stress = stateEngine.currentState.stress
        if stress < 0.35 {
            return "Recovered"
        } else if stress < 0.65 {
            return "Normal"
        } else {
            return "Stressed"
        }
    }

    // MARK: - Album Art Background Gradient

    /// Linear gradient tinted by the artwork accent color.
    /// In dark mode (P2-20), saturation is reduced by 15-20% to prevent
    /// oversaturated gradients on the dark palette.
    private var artworkBackgroundGradient: some View {
        Group {
            if let accentColor = viewModel.artworkAccentColor {
                let adjustedColor = ResonanceColors.darkModeAdjusted(accentColor, for: colorScheme)
                LinearGradient(
                    colors: [adjustedColor.opacity(0.15), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.6), value: viewModel.artworkAccentColor)
            } else {
                Color.clear
            }
        }
    }

    // MARK: - Dominant Color Extraction (P2-21)

    /// Syncs the ambient glow color with the ViewModel's accent color.
    /// The accent color is already extracted by the ViewModel; we use it
    /// directly for the ambient glow to avoid duplicate extraction work.
    private func updateDominantGlowColor() {
        dominantGlowColor = viewModel.artworkAccentColor
    }

    // MARK: - State Info Bar

    private var stateInfoBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(.secondary)
                .font(.caption)

            Text(stateEngine.currentState.context.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("·")
                .foregroundStyle(.secondary)

            Text(stateEngine.currentState.inferredNeed.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.tint)

            Spacer()

            Text("\(Int(stateEngine.currentState.confidence * 100))%")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Context: \(stateEngine.currentState.context.displayName), "
            + "need: \(stateEngine.currentState.inferredNeed.displayName), "
            + "confidence: \(Int(stateEngine.currentState.confidence * 100)) percent"
        )
    }

    // MARK: - Active Playlist Bar

    private var activePlaylistBar: some View {
        Group {
            if let playlistName = viewModel.activePlaylistName {
                HStack {
                    Image(systemName: "music.note.list")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)

                    Text("Playing from: \(playlistName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .glassEffect(.regular.interactive())
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Playing from playlist: \(playlistName)")
            }
        }
    }

    // MARK: - Empty State View

    /// Smart empty state with "Play for Me" hero button and browse playlists fallback.
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated brain icon with pulse ring
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(ResonanceColors.accent.opacity(0.3), lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .scaleEffect(animatePulse ? 1.4 : 1.0)
                    .opacity(animatePulse ? 0 : 0.6)
                    .animation(
                        reduceMotion ? .none : .easeOut(duration: 2).repeatForever(autoreverses: false),
                        value: animatePulse
                    )

                // Inner glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [ResonanceColors.accent.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                // Brain icon
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 44))
                    .foregroundStyle(ResonanceColors.accent)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
            }

            // Greeting text
            VStack(spacing: 8) {
                Text(timeBasedGreeting)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Let Resonance pick the perfect track\nfor how you're feeling right now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            // "Play for Me" hero button
            Button {
                if viewModel.activePlaylistName != nil {
                    viewModel.requestAISelection()
                } else {
                    onBrowsePlaylists?()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "wand.and.stars")
                        .font(.title3)
                    Text("Play for Me")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ResonanceColors.accent.gradient)
                )
                .glassEffect(.regular)
            }
            .padding(.horizontal, 40)
            .accessibilityLabel("Play for Me")
            .accessibilityHint("Let AI select the perfect song for your current state")

            // Secondary: Browse Playlists
            if let onBrowsePlaylists {
                Button(action: onBrowsePlaylists) {
                    HStack(spacing: 6) {
                        Image(systemName: "music.note.list")
                        Text("Browse Playlists")
                    }
                    .font(.subheadline)
                    .foregroundStyle(ResonanceColors.accent)
                }
                .accessibilityLabel("Browse Playlists")
            }

            Spacer()
        }
        .onAppear { animatePulse = true }
    }

    // MARK: - Bottom Action Row

    /// Minimal row with "Why this song?" and "Queue" links.
    private var bottomActionRow: some View {
        HStack {
            if viewModel.currentExplanation != nil {
                Button { showExplanation = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                            .font(.caption)
                        Text("Why?")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(ResonanceColors.accent)
                }
                .accessibilityLabel("Why this song")
                .accessibilityHint("See why AI picked this song")
            }

            Spacer()

            Button { showQueue = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.caption)
                    Text("Queue")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Up Next")
        }
    }

    // MARK: - Explanation Sheet

    /// Full explanation of why the current song was chosen, shown in a sheet.
    private var explanationSheet: some View {
        NavigationStack {
            ScrollView {
                if let explanation = viewModel.currentExplanation {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(explanation.full)
                            .font(.body)
                            .foregroundStyle(.primary.opacity(0.85))
                            .padding(.horizontal)

                        if !explanation.factors.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Factors")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(explanation.factors.prefix(4)) { factor in
                                    factorRow(
                                        factor: factor,
                                        maxContribution: explanation.factors.first?.contribution ?? 1.0
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }

                        aiFeedbackButtons
                            .padding(.top, 8)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Why This Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showExplanation = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Tuning Sheet

    /// DJ tuning sheet with exploration bias slider and volume controls.
    private var tuningSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                explorationBiasControl
                    .padding(.horizontal, 20)

                volumeAndRouteControls
                    .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 20)
            .onAppear { explorationSliderValue = viewModel.explorationBias }
            .navigationTitle("DJ Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showTuning = false }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    /// Returns a time-of-day greeting to personalize the empty state.
    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning! Ready for your morning playlist?"
        case 12..<17:
            return "Good afternoon! Time for some tunes?"
        case 17..<21:
            return "Good evening! Let's set the mood."
        default:
            return "Late night vibes? Let's find the right sound."
        }
    }
}

// MARK: - Hero Artwork Modifier

/// Conditionally applies matchedGeometryEffect when a namespace is provided.
/// This enables the brain-to-artwork transition from the landing screen without
/// requiring a non-optional namespace in views that don't participate in the animation.
private struct HeroArtworkModifier: ViewModifier {
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content
                .matchedGeometryEffect(id: "heroArtwork", in: namespace)
        } else {
            content
        }
    }
}

// MARK: - Preview

#Preview {
    NowPlayingView(
        viewModel: NowPlayingViewModel(musicService: MusicKitService()),
        stateEngine: StateEngine(contextCollector: ContextCollector(), healthKitService: HealthKitService())
    )
}
