//
//  FenixuzForeignUserBannerView.swift
//  Telegram-Mac
//
//  Header banner that warns the user when chatting with someone from a
//  different country. Counterpart of iOS's foreign-user gate.
//
//  Visual: thin orange-tinted bar with a warning icon + localized message.
//  Designed to slot into a chat header / pinned-view stack.
//
//  Wiring (consumer is the ChatController):
//    let banner = FenixuzForeignUserBannerView(frame: ...)
//    banner.configure(for: peer, myPhone: myUserPhone)
//    if banner.shouldShow {
//        chatHeader.addSubview(banner)
//    }
//
//  Or check directly:
//    if FenixuzForeignUserBlock.shouldShowBanner(for: peer, myPhone: myUserPhone) { ... }
//
//  Toggle gate: the `block_foreign_users` Settings switch (UserDefaults suite
//  "pro_messager") opts the user into the banner. When the toggle is OFF, the
//  banner never shows regardless of the peer.

import Cocoa
import TGUIKit
import Postbox
import TelegramCore

public final class FenixuzForeignUserBannerView: View {

    private let iconView: ImageView = ImageView()
    private let messageView: TextView = TextView()
    private let dismissButton: ImageButton = ImageButton()

    public var onDismiss: (() -> Void)?

    public private(set) var shouldShow: Bool = false

    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        self.backgroundColor = NSColor(srgbRed: 1.0, green: 0.6, blue: 0.0, alpha: 0.15)
        self.layer?.cornerRadius = 0

        // Icon — a rounded amber rect with "!" (avoids SF Symbols-on-older-macOS issues).
        if let warn = generateWarningIcon() {
            iconView.image = warn
        }
        iconView.contentGravity = .center
        iconView.frame = NSMakeRect(0, 0, 18, 18)
        addSubview(iconView)

        messageView.isSelectable = false
        addSubview(messageView)

        if let cross = generateDismissIcon() {
            dismissButton.set(image: cross, for: .Normal)
        }
        dismissButton.autohighlight = false
        dismissButton.scaleOnClick = true
        dismissButton.frame = NSMakeRect(0, 0, 20, 20)
        dismissButton.set(handler: { [weak self] _ in
            self?.onDismiss?()
        }, for: .Click)
        addSubview(dismissButton)
    }

    public required init?(coder: NSCoder) { fatalError() }

    private func generateWarningIcon() -> CGImage? {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        let amber = NSColor(srgbRed: 0.95, green: 0.55, blue: 0.0, alpha: 1.0)
        amber.setFill()
        let path = NSBezierPath()
        // Triangle.
        path.move(to: NSPoint(x: 1, y: 2))
        path.line(to: NSPoint(x: 17, y: 2))
        path.line(to: NSPoint(x: 9, y: 16))
        path.close()
        path.fill()
        // Exclamation mark.
        NSColor.white.setFill()
        NSRect(x: 8, y: 7, width: 2, height: 5).fill()
        NSRect(x: 8, y: 4, width: 2, height: 2).fill()
        image.unlockFocus()
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    private func generateDismissIcon() -> CGImage? {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()
        let amberDark = NSColor(srgbRed: 0.55, green: 0.32, blue: 0.0, alpha: 0.7)
        amberDark.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.5
        path.move(to: NSPoint(x: 4, y: 4)); path.line(to: NSPoint(x: 12, y: 12))
        path.move(to: NSPoint(x: 12, y: 4)); path.line(to: NSPoint(x: 4, y: 12))
        path.stroke()
        image.unlockFocus()
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    public override func layout() {
        super.layout()
        let h = bounds.height
        let padding: CGFloat = 12
        iconView.frame = NSMakeRect(padding, (h - 18) / 2, 18, 18)
        dismissButton.frame = NSMakeRect(bounds.width - padding - 20, (h - 20) / 2, 20, 20)
        let textX = iconView.frame.maxX + 8
        let textW = dismissButton.frame.minX - textX - 8
        let attr = NSAttributedString.initialize(
            string: FenixuzL10n.current.foreignUser_bannerMessage,
            color: NSColor(srgbRed: 0.55, green: 0.32, blue: 0.0, alpha: 1.0),
            font: .normal(13)
        )
        let layout = TextViewLayout(attr, alignment: .left)
        layout.measure(width: textW)
        messageView.update(layout)
        messageView.setFrameOrigin(NSMakePoint(textX, (h - messageView.frame.height) / 2))
    }

    /// Decide whether to show the banner for this peer + my-phone pair.
    /// Reads the `block_foreign_users` settings toggle internally. If the toggle
    /// is OFF, `shouldShow` is always false.
    public func configure(for peer: Peer?, myPhone: String?) {
        let enabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "block_foreign_users") ?? false
        if !enabled {
            self.shouldShow = false
            return
        }
        self.shouldShow = isForeignUser(peer: peer, myPhone: myPhone)
    }
}

/// Convenience facade so callers don't need to instantiate a view to query.
public enum FenixuzForeignUserBlock {
    public static func shouldShowBanner(for peer: Peer?, myPhone: String?) -> Bool {
        let enabled = UserDefaults(suiteName: "pro_messager")?.bool(forKey: "block_foreign_users") ?? false
        if !enabled { return false }
        return isForeignUser(peer: peer, myPhone: myPhone)
    }
}
