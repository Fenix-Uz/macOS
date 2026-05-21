//
//  FenixuzChatPincodeViewController.swift
//  Telegram-Mac
//
//  iOS portasi: submodules/Fenixuz/ChatLock/Sources/ChatPincodeViewController.swift
//
//  4-digit pincode entry sheet. Three modes:
//    - .set    — user picks a new pincode (asks twice — confirm)
//    - .verify — gate before unlocking a chat
//    - .remove — verify before deleting the pincode
//
//  Mac AppKit port. Differences vs iOS:
//    - Uses a ModalViewController (centered sheet) instead of full-screen modal.
//    - Number pad uses TextButton instances laid out manually (no UIButton).
//    - Shake animation is a CAKeyframeAnimation on the dots row layer.
//    - No biometric prompt (Touch ID / Face ID) — Mac side is keyboard+mouse
//      first; the iOS biometric block is intentionally omitted. The data
//      manager (`FenixuzChatPincodeManager`) does not encrypt with biometrics
//      either, so no asymmetry is introduced.
//
//  Callers wire pin gate via the helpers at the bottom of this file:
//    FenixuzChatPincode.presentSet(for: window, onSuccess: { code in ... })
//    FenixuzChatPincode.presentVerify(for: window, expecting: { ... }, onSuccess: { ... })
//    FenixuzChatPincode.presentRemove(for: window, expecting: { ... }, onSuccess: { ... })

import Cocoa
import TGUIKit
import Postbox
import TelegramCore

public enum FenixuzChatPincodeMode {
    case set(onSuccess: (String) -> Void)
    case verify(onVerify: (String) -> Bool, onSuccess: () -> Void)
    case remove(onVerify: (String) -> Bool, onSuccess: () -> Void)
}

// MARK: - Pincode view (NSView, hosts the actual UI)

private final class PincodeView: NSView {
    let titleLabel: TextView = TextView()
    let subtitleLabel: TextView = TextView()
    let dotsContainer: NSView = NSView()
    private(set) var dotViews: [NSView] = []
    let padContainer: NSView = NSView()
    let closeButton: ImageButton = ImageButton()

    private let isDark: Bool

    init(isDark: Bool) {
        self.isDark = isDark
        super.init(frame: .zero)

        self.wantsLayer = true
        self.layer?.backgroundColor = (isDark ? NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1.0) : NSColor(srgbRed: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)).cgColor

        // Close button — render a simple X glyph.
        if let xImage = PincodeView.makeCloseIcon(isDark: isDark) {
            closeButton.set(image: xImage, for: .Normal)
        }
        closeButton.autohighlight = false
        closeButton.scaleOnClick = true
        closeButton.frame = NSMakeRect(0, 0, 28, 28)
        addSubview(closeButton)

        // Title.
        titleLabel.isSelectable = false
        addSubview(titleLabel)

        // Subtitle.
        subtitleLabel.isSelectable = false
        addSubview(subtitleLabel)

        // Dots.
        addSubview(dotsContainer)
        for _ in 0..<4 {
            let dot = NSView(frame: NSMakeRect(0, 0, 16, 16))
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 8
            dot.layer?.borderWidth = 2
            dotsContainer.addSubview(dot)
            dotViews.append(dot)
        }

        addSubview(padContainer)
    }

    required init?(coder: NSCoder) { fatalError() }

    static func makeCloseIcon(isDark: Bool) -> CGImage? {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        image.lockFocus()
        let strokeColor = isDark ? NSColor(white: 1, alpha: 0.45) : NSColor(white: 0, alpha: 0.35)
        strokeColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.5
        path.lineCapStyle = .round
        path.move(to: NSPoint(x: 6, y: 6))
        path.line(to: NSPoint(x: 16, y: 16))
        path.move(to: NSPoint(x: 16, y: 6))
        path.line(to: NSPoint(x: 6, y: 16))
        path.stroke()
        image.unlockFocus()
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        let h = bounds.height

        // Close button — top-right.
        closeButton.frame = NSMakeRect(w - 12 - 28, h - 12 - 28, 28, 28)

        // Title — center, top quarter.
        let titleSize = titleLabel.frame.size
        titleLabel.setFrameOrigin(NSMakePoint((w - titleSize.width) / 2, h - 64 - titleSize.height))

        // Subtitle — below title.
        let subSize = subtitleLabel.frame.size
        subtitleLabel.setFrameOrigin(NSMakePoint((w - subSize.width) / 2, titleLabel.frame.minY - 8 - subSize.height))

        // Dots — below subtitle.
        let dotSize: CGFloat = 16
        let dotSpacing: CGFloat = 18
        let dotsWidth = CGFloat(dotViews.count) * dotSize + CGFloat(dotViews.count - 1) * dotSpacing
        dotsContainer.frame = NSMakeRect((w - dotsWidth) / 2, subtitleLabel.frame.minY - 36 - dotSize, dotsWidth, dotSize)
        for (i, dot) in dotViews.enumerated() {
            dot.frame = NSMakeRect(CGFloat(i) * (dotSize + dotSpacing), 0, dotSize, dotSize)
        }

        // Pad — bottom centered.
        let padWidth: CGFloat = 240
        let padHeight: CGFloat = 4 * 56 + 3 * 10
        padContainer.frame = NSMakeRect((w - padWidth) / 2, 28, padWidth, padHeight)
    }
}

// MARK: - Controller

final class FenixuzChatPincodeViewController: ModalViewController {

    private let mode: FenixuzChatPincodeMode

    private var enteredCode: String = ""
    private var firstCode: String = ""
    private var isConfirming: Bool = false

    private var pincodeView: PincodeView!

    init(mode: FenixuzChatPincodeMode) {
        self.mode = mode
        super.init(frame: NSMakeRect(0, 0, 360, 520))
        self.bar = .init(height: 0)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var closable: Bool { return true }

    override func viewClass() -> AnyClass {
        return PincodeView.self
    }

    private var genericView: PincodeView {
        return self.view as! PincodeView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let isDark = presentation.colors.isDark
        self.pincodeView = self.genericView
        // Replace the auto-instantiated view with our isDark-aware one. We use
        // the same class so the cast above is safe.
        // Build the keypad subviews now that view is loaded.
        buildKeypad(isDark: isDark)

        // Close button action.
        genericView.closeButton.set(handler: { [weak self] _ in
            self?.close()
        }, for: .Click)

        // Initial labels + dot colors.
        updateLabels()
        updateDots(animated: false)
        readyOnce()
    }

    private func buildKeypad(isDark: Bool) {
        let pad = genericView.padContainer
        let buttonSize: CGFloat = 56
        let spacing: CGFloat = 10
        let digits: [(String, Int?)] = [
            ("1", 1), ("2", 2), ("3", 3),
            ("4", 4), ("5", 5), ("6", 6),
            ("7", 7), ("8", 8), ("9", 9),
            ("", nil), ("0", 0), ("⌫", -1)
        ]
        for (i, (label, value)) in digits.enumerated() {
            if label.isEmpty { continue }
            let row = i / 3
            let col = i % 3
            let btn = TextButton()
            btn.layer?.cornerRadius = buttonSize / 2
            btn.set(font: .normal(.huge), for: .Normal)
            btn.set(color: isDark ? .white : .black, for: .Normal)
            btn.set(text: label, for: .Normal)
            if label != "⌫" {
                btn.layer?.backgroundColor = (isDark
                    ? NSColor(white: 1, alpha: 0.08)
                    : NSColor(white: 1, alpha: 0.95)).cgColor
                btn.set(background: isDark ? NSColor(white: 1, alpha: 0.08) : NSColor(white: 1, alpha: 0.95), for: .Normal)
                btn.set(background: isDark ? NSColor(white: 1, alpha: 0.16) : NSColor(white: 0.92, alpha: 1), for: .Highlight)
            } else {
                btn.set(background: .clear, for: .Normal)
                btn.set(background: .clear, for: .Highlight)
            }
            btn.autohighlight = label != "⌫"
            btn.scaleOnClick = true
            btn.frame = NSMakeRect(
                CGFloat(col) * (buttonSize + spacing),
                pad.bounds.height - buttonSize - CGFloat(row) * (buttonSize + spacing),
                buttonSize, buttonSize
            )
            // Use a tag to recover the action without capturing a strong ref.
            btn.set(handler: { [weak self] _ in
                guard let self = self else { return }
                if let digit = value, digit >= 0 {
                    self.append(digit)
                } else {
                    self.backspace()
                }
            }, for: .Click)
            pad.addSubview(btn)
        }
    }

    private func updateLabels() {
        let l10n = FenixuzL10n.current
        let isDark = presentation.colors.isDark
        let titleText: String
        let subtitleText: String
        switch mode {
        case .set:
            if isConfirming {
                titleText = l10n.pincode_set_confirmTitle
                subtitleText = l10n.pincode_set_confirmSubtitle
            } else {
                titleText = l10n.pincode_set_title
                subtitleText = l10n.pincode_set_subtitle
            }
        case .verify:
            titleText = l10n.pincode_verify_title
            subtitleText = l10n.pincode_verify_subtitle
        case .remove:
            titleText = l10n.pincode_remove_title
            subtitleText = l10n.pincode_remove_subtitle
        }
        let titleColor: NSColor = isDark ? .white : .black
        let subColor: NSColor = isDark ? NSColor(white: 1, alpha: 0.55) : NSColor(white: 0, alpha: 0.5)
        let titleAttr = NSAttributedString.initialize(string: titleText, color: titleColor, font: .bold(24))
        let titleLayout = TextViewLayout(titleAttr, alignment: .center)
        titleLayout.measure(width: 320)
        genericView.titleLabel.update(titleLayout)
        let subAttr = NSAttributedString.initialize(string: subtitleText, color: subColor, font: .normal(14))
        let subLayout = TextViewLayout(subAttr, alignment: .center)
        subLayout.measure(width: 320)
        genericView.subtitleLabel.update(subLayout)
        genericView.needsLayout = true
    }

    private func updateDots(animated: Bool) {
        let accent = presentation.colors.accent
        let isDark = presentation.colors.isDark
        let emptyBorder = isDark ? NSColor(white: 1, alpha: 0.3) : NSColor(white: 0, alpha: 0.25)
        for (i, dot) in genericView.dotViews.enumerated() {
            let filled = i < enteredCode.count
            let block = {
                dot.layer?.backgroundColor = filled ? accent.cgColor : NSColor.clear.cgColor
                dot.layer?.borderColor = filled ? accent.cgColor : emptyBorder.cgColor
            }
            if animated {
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.15)
                block()
                CATransaction.commit()
            } else {
                block()
            }
        }
    }

    // MARK: - Input

    private func append(_ digit: Int) {
        guard enteredCode.count < 4 else { return }
        enteredCode.append(String(digit))
        updateDots(animated: true)
        if enteredCode.count == 4 {
            processCode()
        }
    }

    private func backspace() {
        guard !enteredCode.isEmpty else { return }
        enteredCode.removeLast()
        updateDots(animated: true)
    }

    private func processCode() {
        switch mode {
        case let .set(onSuccess):
            if !isConfirming {
                firstCode = enteredCode
                enteredCode = ""
                isConfirming = true
                updateLabels()
                updateDots(animated: true)
            } else if enteredCode == firstCode {
                let code = firstCode
                close()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onSuccess(code)
                }
            } else {
                shakeAndReset(message: FenixuzL10n.current.pincode_error_mismatch)
            }

        case let .verify(onVerify, onSuccess):
            if onVerify(enteredCode) {
                close()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onSuccess()
                }
            } else {
                shakeAndReset(message: FenixuzL10n.current.pincode_error_wrong)
            }

        case let .remove(onVerify, onSuccess):
            if onVerify(enteredCode) {
                close()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onSuccess()
                }
            } else {
                shakeAndReset(message: FenixuzL10n.current.pincode_error_wrong)
            }
        }
    }

    private func shakeAndReset(message: String) {
        // Briefly recolor subtitle to indicate the error.
        let isDark = presentation.colors.isDark
        let errColor = NSColor(srgbRed: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)
        let errAttr = NSAttributedString.initialize(string: message, color: errColor, font: .normal(14))
        let errLayout = TextViewLayout(errAttr, alignment: .center)
        errLayout.measure(width: 320)
        genericView.subtitleLabel.update(errLayout)
        genericView.needsLayout = true

        // Shake the dots row.
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.duration = 0.4
        anim.values = [-10, 10, -8, 8, -5, 5, 0]
        genericView.dotsContainer.layer?.add(anim, forKey: "shake")
        _ = isDark

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.enteredCode = ""
            self.isConfirming = false
            self.firstCode = ""
            self.updateLabels()
            self.updateDots(animated: true)
        }
    }
}

// MARK: - Public helper namespace

public enum FenixuzChatPincode {
    public static func presentSet(for window: Window, onSuccess: @escaping (String) -> Void) {
        let controller = FenixuzChatPincodeViewController(mode: .set(onSuccess: onSuccess))
        showModal(with: controller, for: window)
    }

    public static func presentVerify(for window: Window,
                                     verify: @escaping (String) -> Bool,
                                     onSuccess: @escaping () -> Void) {
        let controller = FenixuzChatPincodeViewController(mode: .verify(onVerify: verify, onSuccess: onSuccess))
        showModal(with: controller, for: window)
    }

    public static func presentRemove(for window: Window,
                                     verify: @escaping (String) -> Bool,
                                     onSuccess: @escaping () -> Void) {
        let controller = FenixuzChatPincodeViewController(mode: .remove(onVerify: verify, onSuccess: onSuccess))
        showModal(with: controller, for: window)
    }

    /// Convenience: gate a chat-open call by the per-chat pincode (if any).
    /// If no pincode is set, `onUnlocked` runs immediately. Otherwise, the
    /// verify sheet is presented and `onUnlocked` only runs on correct entry.
    public static func gate(window: Window,
                            chatId: PeerId,
                            manager: FenixuzChatPincodeManager = .shared,
                            onUnlocked: @escaping () -> Void) {
        if !manager.isLocked(chatId) {
            onUnlocked()
            return
        }
        presentVerify(for: window,
                      verify: { code in manager.verify(code, for: chatId) },
                      onSuccess: onUnlocked)
    }
}
