import SwiftUI

struct PillContentView: View {
    var stateMachine: NotchiStateMachine = .shared
    var panelManager: NotchPanelManager = .shared
    var usageService: ClaudeUsageService = .shared
    @Namespace private var glassNamespace
    @State private var showingPanelSettings = false
    @State private var showingSessionActivity = false
    @State private var isMuted = AppSettings.isMuted
    @State private var isActivityCollapsed = false
    @State private var hoveredSessionId: String?
    @State private var isDragging = false

    private var sessionStore: SessionStore {
        stateMachine.sessionStore
    }

    private var isExpanded: Bool { panelManager.isExpanded }

    private var topSession: SessionData? {
        sessionStore.sortedSessions.first
    }

    private var headerSessions: [SessionData] {
        Array(sessionStore.sortedSessions.prefix(2))
    }

    private var statusColor: Color {
        guard let session = topSession else { return TerminalColors.green }
        switch session.task {
        case .working, .compacting:
            return TerminalColors.amber
        case .planning:
            return TerminalColors.planMode
        case .waiting:
            return TerminalColors.red
        default:
            return TerminalColors.green
        }
    }

    private var shouldShowBackButton: Bool {
        showingPanelSettings ||
        (sessionStore.activeSessionCount >= 2 && showingSessionActivity)
    }

    // MARK: - Coordinate conversion

    /// Convert screen rect center to SwiftUI local coordinates within the panel
    private func localCenter(of rect: CGRect, in geo: GeometryProxy) -> CGPoint {
        guard let screen = ScreenSelector.shared.selectedScreen else {
            return CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        let frame = screen.frame
        let x = rect.midX - frame.minX
        let y = frame.maxY - rect.midY
        return CGPoint(x: x, y: y)
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            GlassEffectContainer {
                if isExpanded {
                    expandedView
                        .transition(.opacity)
                        .glassEffect(.regular.tint(.clear), in: .rect(cornerRadius: 20))
                        .glassEffectID("pill", in: glassNamespace)
                        .position(localCenter(of: panelManager.pillExpandedRect, in: geo))
                } else {
                    collapsedPill
                        .transition(.opacity)
                        .glassEffect(.regular.tint(.black.opacity(0.7)), in: .capsule)
                        .glassEffectID("pill", in: glassNamespace)
                        .position(localCenter(of: panelManager.pillRect, in: geo))
                }
            }
            .animation(.spring(duration: 0.5, bounce: 0.15), value: isExpanded)
        }
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .notchiShouldCollapse)) { _ in
            panelManager.collapse()
        }
        .onChange(of: isExpanded) { _, expanded in
            if !expanded {
                showingPanelSettings = false
                showingSessionActivity = false
            }
        }
        .onChange(of: sessionStore.activeSessionCount) { _, count in
            if count < 2 {
                showingSessionActivity = false
            }
        }
    }

    // MARK: - Collapsed Pill

    private var pillDrag: some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                isDragging = true
                guard let screen = ScreenSelector.shared.selectedScreen else { return }
                let screenY = screen.frame.maxY - value.location.y
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                    panelManager.movePill(to: CGPoint(x: value.location.x, y: screenY))
                }
            }
            .onEnded { _ in
                isDragging = false
            }
    }

    private var showSpeechBubble: Bool {
        guard let session = topSession else { return false }
        return session.task == .waiting || !session.pendingQuestions.isEmpty
    }

    private var collapsedPill: some View {
        HStack(spacing: 8) {
            JostlingSpritesView(sessions: headerSessions)

            if showSpeechBubble {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            statusDot
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
        .contentShape(Capsule())
        .onTapGesture {
            panelManager.expand()
        }
        .gesture(pillDrag)
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 7, height: 7)
            .shadow(color: statusColor.opacity(0.6), radius: 2)
    }

    // MARK: - Expanded View

    private var grassHeight: CGFloat {
        expandedPanelHeight * 0.3 + 36
    }

    private var expandedView: some View {
        VStack(spacing: 0) {
            expandedHeader
                .padding(.top, 12)
                .padding(.horizontal, 12)

            ExpandedPanelView(
                sessionStore: sessionStore,
                usageService: usageService,
                showingSettings: $showingPanelSettings,
                showingSessionActivity: $showingSessionActivity,
                isActivityCollapsed: $isActivityCollapsed
            )
            .frame(maxWidth: .infinity)
            .frame(height: expandedPanelHeight)
        }
        .frame(width: NotchConstants.expandedPanelSize.width)
        .background {
            ZStack(alignment: .top) {
                Color.black.opacity(0.8)
                GrassIslandView(
                    sessions: sessionStore.sortedSessions,
                    selectedSessionId: sessionStore.selectedSessionId,
                    hoveredSessionId: hoveredSessionId
                )
                .frame(height: grassHeight, alignment: .bottom)
                .opacity(!showingPanelSettings ? 1 : 0)
            }
        }
        .overlay(alignment: .top) {
            if !showingPanelSettings {
                GrassTapOverlay(
                    sessions: sessionStore.sortedSessions,
                    selectedSessionId: sessionStore.selectedSessionId,
                    hoveredSessionId: $hoveredSessionId,
                    onSelectSession: { sessionId in
                        guard sessionStore.activeSessionCount >= 2 else { return }
                        sessionStore.selectSession(sessionId)
                        showingSessionActivity = true
                    }
                )
                .frame(height: grassHeight, alignment: .bottom)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var expandedPanelHeight: CGFloat {
        let fullHeight = NotchConstants.expandedPanelSize.height - 80
        let collapsedHeight: CGFloat = 155
        return isActivityCollapsed ? collapsedHeight : fullHeight
    }

    private var expandedHeader: some View {
        PanelToolbar(
            isPinned: panelManager.isPinned,
            isMuted: isMuted,
            showBackButton: shouldShowBackButton,
            onPin: { panelManager.togglePin() },
            onMute: toggleMute,
            onSettings: { showingPanelSettings = true },
            onClose: { panelManager.collapse() },
            onBack: goBack
        )
    }

    private func goBack() {
        if showingPanelSettings {
            showingPanelSettings = false
        } else if showingSessionActivity {
            showingSessionActivity = false
            sessionStore.selectSession(nil)
        }
    }

    private func toggleMute() {
        AppSettings.toggleMute()
        isMuted = AppSettings.isMuted
    }
}

#Preview {
    PillContentView()
        .frame(width: 800, height: 600)
}
