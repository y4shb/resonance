//
//  Logging.swift
//  AIDJ
//
//  Unified logging utility for the AI DJ app
//

import Foundation
import os.log

// MARK: - Log Categories

/// Categories for organizing log output
public enum LogCategory: String, CaseIterable {
    case general = "General"
    case stateEngine = "StateEngine"
    case decisionEngine = "DecisionEngine"
    case learning = "Learning"
    case musicKit = "MusicKit"
    case healthKit = "HealthKit"
    case watchConnectivity = "WatchConnectivity"
    case persistence = "Persistence"
    case ui = "UI"
    case background = "Background"
    case network = "Network"

    /// Returns the subsystem identifier for os_log
    var subsystem: String {
        "com.y4sh.resonance.\(rawValue.lowercased())"
    }
}

// MARK: - Log Level

/// Severity levels for log messages
public enum LogLevel: Int, Comparable, CaseIterable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🔥"
        }
    }
}

// MARK: - Logger

/// Main logging interface for the app
public final class Logger: @unchecked Sendable {
    // MARK: - Singleton

    public static let shared = Logger()

    // MARK: - Properties

    private let osLoggers: [LogCategory: OSLog]
    private var minimumLevel: LogLevel = .debug
    private var isEnabled: Bool = true

    #if DEBUG
    private var inMemoryLogs: [LogEntry] = []
    private let maxInMemoryLogs = 1000
    private let logQueue = DispatchQueue(label: "com.y4sh.resonance.logger", qos: .utility)
    #endif

    // MARK: - Initialization

    private init() {
        var loggers: [LogCategory: OSLog] = [:]
        for category in LogCategory.allCases {
            loggers[category] = OSLog(subsystem: category.subsystem, category: category.rawValue)
        }
        self.osLoggers = loggers
    }

    // MARK: - Configuration

    /// Sets the minimum log level (messages below this level are ignored)
    public func setMinimumLevel(_ level: LogLevel) {
        minimumLevel = level
    }

    /// Enables or disables logging
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    // MARK: - Logging Methods

    /// Logs a debug message
    public func debug(
        _ message: String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    /// Logs an info message
    public func info(
        _ message: String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    /// Logs a warning message
    public func warning(
        _ message: String,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    /// Logs an error message
    public func error(
        _ message: String,
        error: Error? = nil,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var fullMessage = message
        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }
        log(fullMessage, level: .error, category: category, file: file, function: function, line: line)
    }

    /// Logs a critical message
    public func critical(
        _ message: String,
        error: Error? = nil,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var fullMessage = message
        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }
        log(fullMessage, level: .critical, category: category, file: file, function: function, line: line)
    }

    // MARK: - Core Logging

    private func log(
        _ message: String,
        level: LogLevel,
        category: LogCategory,
        file: String,
        function: String,
        line: Int
    ) {
        guard isEnabled, level >= minimumLevel else { return }

        let filename = (file as NSString).lastPathComponent
        let formattedMessage = "[\(filename):\(line)] \(function) - \(message)"

        // Log to os_log
        if let osLog = osLoggers[category] {
            os_log("%{public}@", log: osLog, type: level.osLogType, formattedMessage)
        }

        #if DEBUG
        // Also print to console in debug builds
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let consoleMessage = "\(timestamp) \(level.emoji) [\(category.rawValue)] \(formattedMessage)"
        print(consoleMessage)

        // Store in memory for debug UI
        logQueue.async { [weak self] in
            guard let self = self else { return }
            let entry = LogEntry(
                timestamp: Date(),
                level: level,
                category: category,
                message: message,
                file: filename,
                function: function,
                line: line
            )
            self.inMemoryLogs.append(entry)
            if self.inMemoryLogs.count > self.maxInMemoryLogs {
                self.inMemoryLogs.removeFirst()
            }
        }
        #endif
    }

    // MARK: - Debug Utilities

    #if DEBUG
    /// Returns recent log entries (debug builds only)
    public func getRecentLogs(count: Int = 100, category: LogCategory? = nil, minLevel: LogLevel? = nil) -> [LogEntry] {
        logQueue.sync {
            var logs = inMemoryLogs
            if let category = category {
                logs = logs.filter { $0.category == category }
            }
            if let minLevel = minLevel {
                logs = logs.filter { $0.level >= minLevel }
            }
            return Array(logs.suffix(count))
        }
    }

    /// Clears in-memory logs
    public func clearLogs() {
        logQueue.async { [weak self] in
            self?.inMemoryLogs.removeAll()
        }
    }
    #endif
}

// MARK: - Log Entry

#if DEBUG
/// Represents a single log entry (debug builds only)
public struct LogEntry: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let level: LogLevel
    public let category: LogCategory
    public let message: String
    public let file: String
    public let function: String
    public let line: Int

    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }

    public var summary: String {
        "\(level.emoji) [\(category.rawValue)] \(message)"
    }
}
#endif

// MARK: - Convenience Global Functions

/// Global logging functions for convenience
public func logDebug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, category: category, file: file, function: function, line: line)
}

public func logInfo(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, category: category, file: file, function: function, line: line)
}

public func logWarning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, category: category, file: file, function: function, line: line)
}

public func logError(_ message: String, error: Error? = nil, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, error: error, category: category, file: file, function: function, line: line)
}

public func logCritical(_ message: String, error: Error? = nil, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.critical(message, error: error, category: category, file: file, function: function, line: line)
}

// MARK: - Performance Logging

/// Utility for measuring and logging performance
public struct PerformanceLogger {
    private let name: String
    private let category: LogCategory
    private let startTime: CFAbsoluteTime

    public init(_ name: String, category: LogCategory = .general) {
        self.name = name
        self.category = category
        self.startTime = CFAbsoluteTimeGetCurrent()
        Logger.shared.debug("Starting: \(name)", category: category)
    }

    public func end() {
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        Logger.shared.debug("Completed: \(name) in \(String(format: "%.2f", elapsed))ms", category: category)
    }

    public static func measure<T>(_ name: String, category: LogCategory = .general, operation: () throws -> T) rethrows -> T {
        let logger = PerformanceLogger(name, category: category)
        defer { logger.end() }
        return try operation()
    }

    public static func measureAsync<T>(_ name: String, category: LogCategory = .general, operation: () async throws -> T) async rethrows -> T {
        let logger = PerformanceLogger(name, category: category)
        defer { logger.end() }
        return try await operation()
    }
}
