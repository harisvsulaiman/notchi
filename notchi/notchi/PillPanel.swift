import AppKit

/// A borderless, transparent panel positioned at a screen corner for pill mode
final class PillPanel: NSPanel {
    init(frame: CGRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true

        level = .mainMenu + 3
        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle
        ]

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            NotificationCenter.default.post(name: .notchiShouldCollapse, object: nil)
        }
    }
}
