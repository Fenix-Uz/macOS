//
//  FenixuzAIChatbot.swift
//  Telegram-Mac
//
//  iOS parity stub. The iOS Fenixuz fork ships an AI chatbot tab
//  (submodules/Fenixuz/AIChatbot/Sources/AIChatbotTabController.swift) but
//  the UI is intentionally hidden — the module is kept around for future
//  enablement.
//
//  Mac follows the same disposition: the feature is NOT wired into the
//  sidebar. This file exists only so that any future enablement is a
//  one-flag flip away, and so the Fenixuz iOS↔Mac feature inventory shows
//  parity rather than a missing slot.
//
//  When/if we ever ship the AI tab on Mac:
//    1. Flip `isEnabled = true`.
//    2. Insert an entry next to `.chats` / `.contacts` in the main sidebar
//       (MainSplitViewController or the equivalent left-rail controller).
//    3. Provide a real `makeViewController(_:)` that returns a Mac
//       AppKit-based chat surface backed by whichever provider the iOS
//       module ends up using.

import Foundation
import AppKit
import TelegramCore

public enum FenixuzAIChatbot {
    /// Master switch. Stays `false` until product decides to ship the
    /// chatbot on Mac. Mirrors the iOS module's hidden-by-default state.
    public static let isEnabled: Bool = false

    /// Placeholder factory for the eventual sidebar entry. Returns `nil`
    /// while `isEnabled == false` so consumers can safely call this from
    /// the sidebar-building code without conditional imports.
    public static func makeViewController() -> NSViewController? {
        guard isEnabled else { return nil }
        // Real Mac implementation is intentionally deferred — see file header.
        return nil
    }
}
