import AppKit

@MainActor
@Observable
final class NotchPanelManager {
    static let shared = NotchPanelManager()

    private(set) var isExpanded = false
    private(set) var isPinned = false
    private(set) var notchSize: CGSize = .zero
    private(set) var notchRect: CGRect = .zero
    private(set) var panelRect: CGRect = .zero
    private(set) var pillRect: CGRect = .zero
    private(set) var pillExpandedRect: CGRect = .zero
    /// Custom pill origin set by dragging (screen coordinates of pill center)
    private(set) var pillOrigin: CGPoint?
    private var screenHeight: CGFloat = 0

    var displayMode: DisplayMode = AppSettings.displayMode

    /// Callbacks for AppDelegate to show/hide panels
    var onDisplayModeChanged: (() -> Void)?
    var onPillCornerChanged: (() -> Void)?

    private var mouseDownMonitor: EventMonitor?

    private init() {
        setupEventMonitors()
    }

    func updateGeometry(for screen: NSScreen) {
        let newNotchSize = screen.notchSize
        let screenFrame = screen.frame

        notchSize = newNotchSize

        // Notch geometry
        let notchCenterX = screenFrame.origin.x + screenFrame.width / 2
        let sideWidth = max(0, newNotchSize.height - 12) + 24
        let notchTotalWidth = newNotchSize.width + sideWidth

        notchRect = CGRect(
            x: notchCenterX - notchTotalWidth / 2,
            y: screenFrame.maxY - newNotchSize.height,
            width: notchTotalWidth,
            height: newNotchSize.height
        )

        let panelSize = NotchConstants.expandedPanelSize
        let panelWidth = panelSize.width + NotchConstants.expandedPanelHorizontalPadding
        panelRect = CGRect(
            x: notchCenterX - panelWidth / 2,
            y: screenFrame.maxY - panelSize.height,
            width: panelWidth,
            height: panelSize.height
        )

        screenHeight = screenFrame.height

        // Pill geometry
        updatePillGeometry(for: screen)
    }

    static let pillWidth: CGFloat = 60
    static let pillHeight: CGFloat = 36
    private static let pillMargin: CGFloat = 16

    func updatePillGeometry(for screen: NSScreen) {
        let fullFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        let pillX: CGFloat
        let pillY: CGFloat

        if let origin = pillOrigin {
            // Use custom dragged position, clamped to full screen frame (allows below dock)
            pillX = min(max(origin.x - Self.pillWidth / 2, fullFrame.minX + Self.pillMargin),
                        fullFrame.maxX - Self.pillWidth - Self.pillMargin)
            pillY = min(max(origin.y - Self.pillHeight / 2, fullFrame.minY + Self.pillMargin),
                        fullFrame.maxY - Self.pillHeight - Self.pillMargin)
        } else {
            let corner = AppSettings.pillCorner
            switch corner {
            case .bottomRight:
                pillX = visibleFrame.maxX - Self.pillWidth - Self.pillMargin
            case .bottomLeft:
                pillX = visibleFrame.minX + Self.pillMargin
            }
            pillY = fullFrame.minY + Self.pillMargin
        }

        pillRect = CGRect(x: pillX, y: pillY, width: Self.pillWidth, height: Self.pillHeight)

        // Expanded rect grows upward from the pill
        let expandedWidth: CGFloat = NotchConstants.expandedPanelSize.width + 48
        let expandedHeight: CGFloat = NotchConstants.expandedPanelSize.height + 20
        let pillCenterX = pillX + Self.pillWidth / 2
        let expandedX = min(max(pillCenterX - expandedWidth / 2, fullFrame.minX + 4),
                            fullFrame.maxX - expandedWidth - 4)
        let expandedY = pillY

        pillExpandedRect = CGRect(x: expandedX, y: expandedY, width: expandedWidth, height: expandedHeight)
    }

    func movePill(to screenPoint: CGPoint) {
        pillOrigin = screenPoint
        guard let screen = ScreenSelector.shared.selectedScreen else { return }
        updatePillGeometry(for: screen)
        onPillCornerChanged?()
    }

    func updatePillCorner(_ corner: PillCorner) {
        AppSettings.pillCorner = corner
        pillOrigin = nil
        guard let screen = ScreenSelector.shared.selectedScreen else { return }
        updatePillGeometry(for: screen)
        onPillCornerChanged?()
    }

    func switchMode(to mode: DisplayMode) {
        isExpanded = false
        isPinned = false
        displayMode = mode
        AppSettings.displayMode = mode
        onDisplayModeChanged?()
    }

    private func setupEventMonitors() {
        mouseDownMonitor = EventMonitor(mask: .leftMouseDown) { [weak self] _ in
            Task { @MainActor in
                self?.handleMouseDown()
            }
        }
        mouseDownMonitor?.start()
    }

    private func handleMouseDown() {
        let location = NSEvent.mouseLocation

        if displayMode == .pill {
            // Pill expand is handled by tap gesture in PillContentView
            // Only handle collapse on outside click here
            if isExpanded {
                if !isPinned && !pillExpandedRect.contains(location) {
                    collapse()
                }
            }
        } else {
            if isExpanded {
                if !isPinned && !panelRect.contains(location) {
                    collapse()
                }
            } else {
                if notchRect.contains(location) {
                    expand()
                }
            }
        }
    }

    func expand() {
        guard !isExpanded else { return }
        isExpanded = true
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        isPinned = false
    }

    func toggle() {
        if isExpanded {
            collapse()
        } else {
            expand()
        }
    }

    func togglePin() {
        isPinned.toggle()
    }
}

