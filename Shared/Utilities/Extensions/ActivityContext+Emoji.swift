//
//  ActivityContext+Emoji.swift
//  Resonance
//
//  Shared emoji representation for ActivityContext, used by widgets and complications
//

import Foundation

extension ActivityContext {
    /// A representative emoji for this activity context (used in widgets, complications, etc.).
    var emoji: String {
        switch self {
        case .workout: return "\u{1F3C3}"
        case .postWorkout: return "\u{1F4AA}"
        case .deepWork: return "\u{1F9E0}"
        case .work: return "\u{1F4BC}"
        case .commute: return "\u{1F697}"
        case .preSleep: return "\u{1F319}"
        case .morning: return "\u{2600}\u{FE0F}"
        case .relaxation: return "\u{1F9D8}"
        default: return "\u{1F3B5}"
        }
    }
}
