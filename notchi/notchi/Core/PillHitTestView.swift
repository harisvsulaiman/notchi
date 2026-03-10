import AppKit

final class PillHitTestView: NSView {
    weak var panelManager: NotchPanelManager?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let window, let manager = panelManager else { return nil }
        let screenPoint = window.convertPoint(toScreen: convert(point, to: nil))
        let activeRect = manager.isExpanded ? manager.pillExpandedRect : manager.pillRect
        guard activeRect.contains(screenPoint) else { return nil }
        return super.hitTest(point)
    }
}
