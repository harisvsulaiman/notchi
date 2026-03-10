import AppKit
import Sparkle
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchPanel: NotchPanel?
    private var pillPanel: PillPanel?
    private let windowHeight: CGFloat = 500
    private let pillWindowSize: CGFloat = 500

    private let updater: SPUUpdater
    private let userDriver: NotchUserDriver

    override init() {
        userDriver = NotchUserDriver()
        updater = SPUUpdater(
            hostBundle: Bundle.main,
            applicationBundle: Bundle.main,
            userDriver: userDriver,
            delegate: nil
        )
        super.init()

        UpdateManager.shared.setUpdater(updater)

        do {
            try updater.start()
        } catch {
            print("Failed to start Sparkle updater: \(error)")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        setupNotchWindow()
        observeScreenChanges()
        startHookServices()
        startUsageService()
        updater.checkForUpdates()
        SoundService.shared.playStartupSound()
    }

    private func startHookServices() {
        HookInstaller.installIfNeeded()
        SocketServer.shared.start { event in
            Task { @MainActor in
                NotchiStateMachine.shared.handleEvent(event)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @MainActor private func setupNotchWindow() {
        ScreenSelector.shared.refreshScreens()
        guard let screen = ScreenSelector.shared.selectedScreen else { return }
        NotchPanelManager.shared.updateGeometry(for: screen)

        // Create notch panel
        let panel = NotchPanel(frame: notchWindowFrame(for: screen))

        let contentView = NotchContentView()
        let hostingView = NSHostingView(rootView: contentView)

        let hitTestView = NotchHitTestView()
        hitTestView.panelManager = NotchPanelManager.shared
        hitTestView.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: hitTestView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: hitTestView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: hitTestView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: hitTestView.trailingAnchor),
        ])

        panel.contentView = hitTestView
        self.notchPanel = panel

        // Create pill panel
        let pill = PillPanel(frame: pillFrame(for: screen))

        let pillContentView = PillContentView()
        let pillHostingView = NSHostingView(rootView: pillContentView)

        let pillHitTestView = PillHitTestView()
        pillHitTestView.panelManager = NotchPanelManager.shared
        pillHitTestView.addSubview(pillHostingView)
        pillHostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pillHostingView.topAnchor.constraint(equalTo: pillHitTestView.topAnchor),
            pillHostingView.bottomAnchor.constraint(equalTo: pillHitTestView.bottomAnchor),
            pillHostingView.leadingAnchor.constraint(equalTo: pillHitTestView.leadingAnchor),
            pillHostingView.trailingAnchor.constraint(equalTo: pillHitTestView.trailingAnchor),
        ])

        pill.contentView = pillHitTestView
        self.pillPanel = pill

        // Wire up mode/corner change callbacks
        NotchPanelManager.shared.onDisplayModeChanged = { [weak self] in
            self?.showActivePanel()
        }
        NotchPanelManager.shared.onPillCornerChanged = { [weak self] in
            guard let self, let screen = ScreenSelector.shared.selectedScreen else { return }
            self.pillPanel?.setFrame(self.pillFrame(for: screen), display: true)
        }

        // Show the active panel
        showActivePanel()
    }

    @MainActor private func showActivePanel() {
        let mode = NotchPanelManager.shared.displayMode
        if mode == .notch {
            pillPanel?.alphaValue = 0
            pillPanel?.orderOut(nil)
            notchPanel?.alphaValue = 1
            notchPanel?.orderFrontRegardless()
        } else {
            notchPanel?.alphaValue = 0
            notchPanel?.orderOut(nil)
            pillPanel?.alphaValue = 1
            pillPanel?.orderFrontRegardless()
        }
    }

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(repositionWindow),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func repositionWindow() {
        MainActor.assumeIsolated {
            ScreenSelector.shared.refreshScreens()
            guard let screen = ScreenSelector.shared.selectedScreen else { return }

            NotchPanelManager.shared.updateGeometry(for: screen)
            notchPanel?.setFrame(notchWindowFrame(for: screen), display: true)
            pillPanel?.setFrame(pillFrame(for: screen), display: true)
        }
    }

    private func notchWindowFrame(for screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        return NSRect(
            x: screenFrame.origin.x,
            y: screenFrame.maxY - windowHeight,
            width: screenFrame.width,
            height: windowHeight
        )
    }

    private func pillFrame(for screen: NSScreen) -> NSRect {
        // Use the full screen frame so the pill can appear below the dock
        let frame = screen.frame
        return NSRect(
            x: frame.origin.x,
            y: frame.origin.y,
            width: frame.width,
            height: frame.height
        )
    }

    @MainActor private func startUsageService() {
        ClaudeUsageService.shared.startPolling()
    }

}
