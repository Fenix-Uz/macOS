//
//  FenixuzTasksTabIcon.swift
//  Telegram-Mac
//
//  Generated CGImage pair for the Tasks tab icon — a checklist glyph. iOS
//  uses a bundled PDF; we draw the same shape at runtime so we don't have
//  to ship a new asset.

import Cocoa

enum FenixuzTasksTabIcon {
    /// Returns (idleImage, activeImage) for the tab bar at the canonical 22x22
    /// size matching the other Telegram-Mac tab icons.
    static func icons(accent: NSColor, idle: NSColor) -> (CGImage, CGImage) {
        return (draw(color: idle), draw(color: accent))
    }

    private static func draw(color: NSColor) -> CGImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        image.lockFocus()

        color.setStroke()
        color.setFill()

        // Clipboard outline.
        let outer = NSBezierPath(roundedRect: NSRect(x: 3.5, y: 2.5, width: 15, height: 17), xRadius: 2.5, yRadius: 2.5)
        outer.lineWidth = 1.5
        outer.stroke()

        // Clip at top of clipboard.
        let clip = NSBezierPath(roundedRect: NSRect(x: 7.5, y: 17.5, width: 7, height: 2.5), xRadius: 1, yRadius: 1)
        clip.fill()

        // Three check marks (small horizontal lines indicating list items).
        let listYs: [CGFloat] = [13, 9.5, 6]
        for y in listYs {
            // Small box on the left ("checkmark target").
            let box = NSBezierPath(rect: NSRect(x: 6, y: y - 0.75, width: 2.5, height: 2.5))
            box.lineWidth = 1
            box.stroke()
            // Horizontal line on the right ("item label").
            let line = NSBezierPath()
            line.move(to: NSPoint(x: 10, y: y + 0.25))
            line.line(to: NSPoint(x: 16, y: y + 0.25))
            line.lineWidth = 1.2
            line.stroke()
        }

        image.unlockFocus()
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    }
}
