//
//  WeatherService.swift
//  Resonance
//
//  Weather-reactive influence for AI DJ music selection.
//  Fetches current weather conditions via WeatherKit and maps them
//  to music parameter modifiers (valence, energy, tempo, genre hints).
//  Uses CLLocationManager for the user's current location.
//  (E9: Weather-Reactive Influence)
//

#if os(iOS) || os(watchOS)

import Foundation
import CoreLocation
#if canImport(WeatherKit)
import WeatherKit
#endif

// MARK: - Weather Condition Category

/// Categorizes weather conditions into musically meaningful groups.
public enum WeatherConditionCategory: String, Codable, CaseIterable, Sendable {
    case clear = "clear"
    case cloudy = "cloudy"
    case rain = "rain"
    case storm = "storm"
    case snow = "snow"
    case fog = "fog"
    case wind = "wind"
    case extreme = "extreme"

    public var displayName: String {
        switch self {
        case .clear:   return "Clear"
        case .cloudy:  return "Cloudy"
        case .rain:    return "Rain"
        case .storm:   return "Storm"
        case .snow:    return "Snow"
        case .fog:     return "Fog"
        case .wind:    return "Wind"
        case .extreme: return "Extreme"
        }
    }
}

// MARK: - Weather Music Influence

/// Music parameter modifiers derived from the current weather condition.
/// Each modifier ranges from -1.0 to 1.0 and is blended into the
/// song-ranking pipeline at a configurable weight (default 20-30%).
public struct WeatherMusicInfluence: Codable, Sendable, Equatable {

    /// Valence modifier (-1.0 to 1.0). Negative = moodier, positive = uplifting.
    public let valenceModifier: Double

    /// Energy modifier (-1.0 to 1.0). Negative = calmer, positive = higher-energy.
    public let energyModifier: Double

    /// Tempo modifier (-1.0 to 1.0). Negative = slower, positive = faster.
    public let tempoModifier: Double

    /// Genre hints that pair well with the current weather (soft suggestions).
    public let preferredGenreHints: [String]

    /// The weather condition that produced this influence.
    public let condition: WeatherConditionCategory

    /// Neutral influence (all-zero modifiers). Fallback when weather is unavailable.
    public static let neutral = WeatherMusicInfluence(
        valenceModifier: 0,
        energyModifier: 0,
        tempoModifier: 0,
        preferredGenreHints: [],
        condition: .clear
    )

    public init(
        valenceModifier: Double,
        energyModifier: Double,
        tempoModifier: Double,
        preferredGenreHints: [String],
        condition: WeatherConditionCategory
    ) {
        self.valenceModifier = max(-1.0, min(1.0, valenceModifier))
        self.energyModifier = max(-1.0, min(1.0, energyModifier))
        self.tempoModifier = max(-1.0, min(1.0, tempoModifier))
        self.preferredGenreHints = preferredGenreHints
        self.condition = condition
    }
}

// MARK: - Weather Constants

/// Configuration constants for the weather influence subsystem.
public enum WeatherConstants {

    /// Cache validity duration (seconds). Default 30 minutes.
    public static let cacheDurationSeconds: TimeInterval = 1800
    /// Default blend weight (20-30% range).
    public static let defaultBlendWeight: Double = 0.25
    /// Minimum blend weight.
    public static let minimumBlendWeight: Double = 0.0
    /// Maximum blend weight.
    public static let maximumBlendWeight: Double = 0.50
    /// Minimum interval between weather update requests (seconds).
    public static let minimumUpdateInterval: TimeInterval = 900
    /// Desired location accuracy for weather lookups.
    public static let locationAccuracy: CLLocationAccuracy = kCLLocationAccuracyKilometer
}

// MARK: - Weather Service

/// Thread-safe service that fetches current weather conditions and maps them
/// to music-influencing parameters. Uses WeatherKit (iOS 16+) when available,
/// with graceful fallback to neutral modifiers.
/// Privacy: Requires `NSLocationWhenInUseUsageDescription` in Info.plist.
@available(iOS 16.0, watchOS 9.0, *)
public actor WeatherService {

    // MARK: - Cached State

    private var cachedInfluence: WeatherMusicInfluence = .neutral
    private var lastFetchDate: Date?
    private var lastLocation: CLLocation?
    private let locationDelegate: WeatherLocationDelegate

    // MARK: - Initialization

    public init() {
        self.locationDelegate = WeatherLocationDelegate()
        logInfo("WeatherService initialized", category: .general)
    }

    // MARK: - Public API

    /// Returns the current weather-based music influence.
    /// Uses cached data if within `WeatherConstants.cacheDurationSeconds`.
    public func currentInfluence() async -> WeatherMusicInfluence {
        if let lastFetch = lastFetchDate,
           Date().timeIntervalSince(lastFetch) < WeatherConstants.cacheDurationSeconds {
            return cachedInfluence
        }

        return await fetchAndCacheInfluence()
    }

    /// Forces a weather update regardless of cache state.
    @discardableResult
    public func forceUpdate() async -> WeatherMusicInfluence {
        return await fetchAndCacheInfluence()
    }

    /// Returns the blend weight from user preferences, clamped to valid range.
    public nonisolated func blendWeight(from preferences: UserPreferences) -> Double {
        guard preferences.weatherInfluenceEnabled else { return 0.0 }
        return max(
            WeatherConstants.minimumBlendWeight,
            min(WeatherConstants.maximumBlendWeight, preferences.weatherInfluenceWeight)
        )
    }

    /// Whether the service has valid cached data.
    public var hasCachedData: Bool {
        guard let lastFetch = lastFetchDate else { return false }
        return Date().timeIntervalSince(lastFetch) < WeatherConstants.cacheDurationSeconds
    }

    /// The currently cached condition category, if any.
    public var currentCondition: WeatherConditionCategory? {
        guard hasCachedData else { return nil }
        return cachedInfluence.condition
    }

    // MARK: - Fetch & Cache

    private func fetchAndCacheInfluence() async -> WeatherMusicInfluence {
        // 1. Obtain location
        guard let location = await requestLocation() else {
            logDebug(
                "WeatherService: no location available, returning neutral influence",
                category: .general
            )
            return .neutral
        }

        lastLocation = location

        // 2. Fetch weather via WeatherKit
        let condition = await fetchWeatherCondition(at: location)

        // Privacy: don't cache location
        self.lastLocation = nil

        // 3. Map condition to music influence
        let influence = Self.mapConditionToInfluence(condition)

        // 4. Cache
        cachedInfluence = influence
        lastFetchDate = Date()

        logInfo(
            "WeatherService: updated condition=\(condition.rawValue), "
            + "valence=\(String(format: "%+.2f", influence.valenceModifier)), "
            + "energy=\(String(format: "%+.2f", influence.energyModifier)), "
            + "tempo=\(String(format: "%+.2f", influence.tempoModifier))",
            category: .general
        )

        return influence
    }

    // MARK: - Location

    private func requestLocation() async -> CLLocation? {
        return await locationDelegate.requestCurrentLocation()
    }

    // MARK: - WeatherKit Fetch

    private func fetchWeatherCondition(at location: CLLocation) async -> WeatherConditionCategory {
        #if canImport(WeatherKit)
        return await fetchFromWeatherKit(at: location)
        #else
        logDebug(
            "WeatherService: WeatherKit not available, returning .clear fallback",
            category: .general
        )
        return .clear
        #endif
    }

    #if canImport(WeatherKit)
    private func fetchFromWeatherKit(at location: CLLocation) async -> WeatherConditionCategory {
        do {
            let weatherService = WeatherKit.WeatherService.shared
            let weather = try await weatherService.weather(for: location)
            let current = weather.currentWeather
            let category = Self.classifyWeatherKitCondition(current.condition)

            logDebug(
                "WeatherKit condition: \(current.condition), "
                + "classified as: \(category.rawValue), "
                + "temp: \(String(format: "%.1f", current.temperature.value))C",
                category: .general
            )

            return category
        } catch {
            logError(
                "WeatherKit fetch failed, using fallback",
                error: error,
                category: .general
            )
            return .clear
        }
    }

    /// Maps WeatherKit's `WeatherCondition` enum to our simplified category.
    private static func classifyWeatherKitCondition(
        _ condition: WeatherKit.WeatherCondition
    ) -> WeatherConditionCategory {
        switch condition {
        // Clear/sunny
        case .clear, .mostlyClear, .hot:
            return .clear

        // Cloudy
        case .partlyCloudy, .mostlyCloudy, .cloudy:
            return .cloudy

        // Rain
        case .drizzle, .rain, .heavyRain, .freezingDrizzle, .freezingRain:
            return .rain

        // Storm
        case .strongStorms, .thunderstorms, .isolatedThunderstorms,
             .scatteredThunderstorms, .tropicalStorm, .hurricane:
            return .storm

        // Snow
        case .snow, .heavySnow, .flurries, .sleet,
             .blizzard, .blowingSnow, .wintryMix:
            return .snow

        // Fog
        case .foggy, .haze, .smoky:
            return .fog

        // Wind
        case .windy, .breezy, .blowingDust:
            return .wind

        // Extreme
        case .frigid, .hail, .sunShowers, .sunFlurries:
            return .extreme

        @unknown default:
            return .cloudy
        }
    }
    #endif

    // MARK: - Weather-to-Music Mapping

    /// Maps a weather condition category to concrete music influence modifiers.
    public static func mapConditionToInfluence(
        _ condition: WeatherConditionCategory
    ) -> WeatherMusicInfluence {
        switch condition {
        case .clear:
            return WeatherMusicInfluence(
                valenceModifier: +0.10,
                energyModifier: +0.05,
                tempoModifier: +0.05,
                preferredGenreHints: ["pop", "indie", "feel-good"],
                condition: .clear
            )

        case .cloudy:
            return WeatherMusicInfluence(
                valenceModifier: -0.05,
                energyModifier: 0.0,
                tempoModifier: 0.0,
                preferredGenreHints: ["indie", "alternative"],
                condition: .cloudy
            )

        case .rain:
            return WeatherMusicInfluence(
                valenceModifier: -0.15,
                energyModifier: -0.10,
                tempoModifier: -0.10,
                preferredGenreHints: ["acoustic", "ambient", "lo-fi"],
                condition: .rain
            )

        case .storm:
            return WeatherMusicInfluence(
                valenceModifier: -0.05,
                energyModifier: +0.10,
                tempoModifier: +0.05,
                preferredGenreHints: ["dramatic", "cinematic", "electronic"],
                condition: .storm
            )

        case .snow:
            return WeatherMusicInfluence(
                valenceModifier: 0.0,
                energyModifier: -0.15,
                tempoModifier: -0.10,
                preferredGenreHints: ["calm", "ambient", "classical"],
                condition: .snow
            )

        case .fog:
            return WeatherMusicInfluence(
                valenceModifier: -0.10,
                energyModifier: -0.15,
                tempoModifier: -0.10,
                preferredGenreHints: ["atmospheric", "ambient", "post-rock"],
                condition: .fog
            )

        case .wind:
            return WeatherMusicInfluence(
                valenceModifier: -0.05,
                energyModifier: +0.05,
                tempoModifier: +0.05,
                preferredGenreHints: ["rock", "folk", "indie"],
                condition: .wind
            )

        case .extreme:
            return WeatherMusicInfluence(
                valenceModifier: -0.10,
                energyModifier: +0.15,
                tempoModifier: +0.10,
                preferredGenreHints: ["dramatic", "cinematic", "electronic"],
                condition: .extreme
            )
        }
    }
}

// MARK: - Location Delegate

/// Bridges CLLocationManager delegate callbacks into async/await.
@available(iOS 16.0, watchOS 9.0, *)
private final class WeatherLocationDelegate: NSObject,
    CLLocationManagerDelegate, @unchecked Sendable {

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = WeatherConstants.locationAccuracy
    }

    /// Requests the user's current location asynchronously.
    /// Returns nil if authorization is denied or location cannot be determined.
    func requestCurrentLocation() async -> CLLocation? {
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            // Request authorization first, then attempt location
            return await withCheckedContinuation { continuation in
                self.locationContinuation = continuation
                DispatchQueue.main.async {
                    self.locationManager.requestWhenInUseAuthorization()
                }
            }

        case .authorizedWhenInUse, .authorizedAlways:
            return await withCheckedContinuation { continuation in
                self.locationContinuation = continuation
                DispatchQueue.main.async {
                    self.locationManager.requestLocation()
                }
            }

        case .denied, .restricted:
            logDebug(
                "WeatherService: location authorization denied/restricted",
                category: .general
            )
            return nil

        @unknown default:
            return nil
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        let location = locations.last
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        logError(
            "WeatherService: location request failed",
            error: error,
            category: .general
        )
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        logDebug(
            "WeatherService: location authorization changed to \(status.rawValue)",
            category: .general
        )

        // If we were waiting for authorization and got it, request location
        if locationContinuation != nil {
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                DispatchQueue.main.async {
                    manager.requestLocation()
                }
            case .denied, .restricted:
                locationContinuation?.resume(returning: nil)
                locationContinuation = nil
            default:
                break
            }
        }
    }
}

// MARK: - Convenience Extension

@available(iOS 16.0, watchOS 9.0, *)
extension WeatherMusicInfluence {

    /// Scales modifiers by the given blend weight (0.0 - 1.0).
    public func scaled(by weight: Double) -> WeatherMusicInfluence {
        let clampedWeight = max(0.0, min(1.0, weight))
        return WeatherMusicInfluence(
            valenceModifier: valenceModifier * clampedWeight,
            energyModifier: energyModifier * clampedWeight,
            tempoModifier: tempoModifier * clampedWeight,
            preferredGenreHints: clampedWeight > 0.1 ? preferredGenreHints : [],
            condition: condition
        )
    }
}

#endif
