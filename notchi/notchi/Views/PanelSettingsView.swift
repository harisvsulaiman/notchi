import ServiceManagement
import SwiftUI

struct PanelSettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var hooksInstalled = HookInstaller.isInstalled()
    @State private var hooksError = false
    @State private var apiKeyInput = AppSettings.anthropicApiKey ?? ""
    @State private var selectedMode = AppSettings.emotionAnalysisMode
    @State private var displayMode = AppSettings.displayMode
    @State private var pillCorner = AppSettings.pillCorner
    @State private var selectedSound = AppSettings.notificationSound
    @ObservedObject private var screenSelector = ScreenSelector.shared
    @ObservedObject private var updateManager = UpdateManager.shared
    private var usageConnected: Bool { ClaudeUsageService.shared.isConnected }
    private var hasApiKey: Bool { !apiKeyInput.isEmpty }

    private var hookStatusText: String {
        if hooksError { return "Error" }
        if hooksInstalled { return "Installed" }
        return "Not Installed"
    }

    private var hookStatusColor: Color {
        hooksInstalled && !hooksError ? TerminalColors.green : TerminalColors.red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    displaySection
                    Divider().background(Color.white.opacity(0.08))
                    togglesSection
                    Divider().background(Color.white.opacity(0.08))
                    actionsSection
                }
                .padding(.top, 10)
            }
            .scrollIndicators(.hidden)

            Spacer()

            quitSection
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Display Section

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRowView(icon: "rectangle.on.rectangle", title: "Display Mode") {
                SegmentedPicker(
                    selection: $displayMode,
                    options: [(.notch, "Notch"), (.pill, "Pill")]
                )
                .onChange(of: displayMode) { _, mode in
                    NotchPanelManager.shared.switchMode(to: mode)
                }
            }

            if displayMode == .pill {
                SettingsRowView(icon: "arrow.down.right.square", title: "Corner") {
                    SegmentedPicker(
                        selection: $pillCorner,
                        options: [(.bottomLeft, "Left"), (.bottomRight, "Right")]
                    )
                    .onChange(of: pillCorner) { _, corner in
                        NotchPanelManager.shared.updatePillCorner(corner)
                    }
                }
            }

            SettingsRowView(icon: "display", title: "Screen") {
                Menu {
                    Button {
                        screenSelector.selectAutomatic()
                        triggerWindowRecreation()
                    } label: {
                        if screenSelector.selectionMode == .automatic {
                            Label("Automatic", systemImage: "checkmark")
                        } else {
                            Text("Automatic")
                        }
                    }
                    Divider()
                    ForEach(screenSelector.availableScreens, id: \.localizedName) { screen in
                        Button {
                            screenSelector.selectScreen(screen)
                            triggerWindowRecreation()
                        } label: {
                            if screenSelector.isSelected(screen) && screenSelector.selectionMode == .specificScreen {
                                Label(screen.localizedName, systemImage: "checkmark")
                            } else {
                                Text(screen.localizedName)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(screenPickerLabel)
                            .font(.system(size: 11))
                            .foregroundColor(TerminalColors.secondaryText)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(TerminalColors.dimmedText)
                    }
                }
                .menuStyle(.borderlessButton)
            }

            SettingsRowView(icon: "speaker.wave.2", title: "Sound") {
                Menu {
                    ForEach(NotificationSound.allCases, id: \.self) { sound in
                        Button {
                            selectedSound = sound
                            AppSettings.notificationSound = sound
                            SoundService.shared.previewSound(sound)
                        } label: {
                            if selectedSound == sound {
                                Label(sound.displayName, systemImage: "checkmark")
                            } else {
                                Text(sound.displayName)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedSound.displayName)
                            .font(.system(size: 11))
                            .foregroundColor(TerminalColors.secondaryText)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(TerminalColors.dimmedText)
                    }
                }
                .menuStyle(.borderlessButton)
            }
        }
    }

    private var screenPickerLabel: String {
        if screenSelector.selectionMode == .automatic {
            return "Auto"
        }
        return screenSelector.selectedScreen?.localizedName ?? "Auto"
    }

    // MARK: - Toggles Section

    private var togglesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { toggleLaunchAtLogin(!launchAtLogin) }) {
                SettingsRowView(icon: "power", title: "Launch at Login") {
                    ToggleSwitch(isOn: launchAtLogin)
                }
            }
            .buttonStyle(.plain)

            Button(action: installHooksIfNeeded) {
                SettingsRowView(icon: "terminal", title: "Hooks") {
                    statusBadge(hookStatusText, color: hookStatusColor)
                }
            }
            .buttonStyle(.plain)

            Button(action: connectUsage) {
                SettingsRowView(icon: "gauge.with.dots.needle.33percent", title: "Claude Usage") {
                    statusBadge(
                        usageConnected ? "Connected" : "Not Connected",
                        color: usageConnected ? TerminalColors.green : TerminalColors.red
                    )
                }
            }
            .buttonStyle(.plain)

            emotionAnalysisSection
        }
    }

    private var emotionStatusText: String {
        switch selectedMode {
        case .simple: return "Active"
        case .api: return hasApiKey ? "Active" : "No Key"
        case .disabled: return "Disabled"
        }
    }

    private var emotionStatusColor: Color {
        switch selectedMode {
        case .simple: return TerminalColors.green
        case .api: return hasApiKey ? TerminalColors.green : TerminalColors.red
        case .disabled: return TerminalColors.dimmedText
        }
    }

    private var emotionAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsRowView(icon: "brain", title: "Emotion Analysis") {
                statusBadge(emotionStatusText, color: emotionStatusColor)
            }

            HStack(spacing: 4) {
                ForEach(EmotionAnalysisMode.allCases, id: \.self) { mode in
                    Button(action: {
                        selectedMode = mode
                        AppSettings.emotionAnalysisMode = mode
                    }) {
                        Text(mode.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(selectedMode == mode
                                ? TerminalColors.primaryText
                                : TerminalColors.dimmedText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedMode == mode
                                ? Color.white.opacity(0.12)
                                : Color.clear)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 28)

            if selectedMode == .api {
                HStack(spacing: 6) {
                    SecureField("", text: $apiKeyInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(TerminalColors.primaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                        .onSubmit { saveApiKey() }
                        .overlay(alignment: .leading) {
                            if apiKeyInput.isEmpty {
                                Text("Anthropic API Key")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(TerminalColors.dimmedText)
                                    .padding(.leading, 8)
                                    .allowsHitTesting(false)
                            }
                        }

                    Button(action: saveApiKey) {
                        Image(systemName: hasApiKey ? "checkmark.circle.fill" : "arrow.right.circle")
                            .font(.system(size: 14))
                            .foregroundColor(hasApiKey ? TerminalColors.green : TerminalColors.dimmedText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 28)
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { updateManager.checkForUpdates() }) {
                SettingsRowView(icon: "arrow.triangle.2.circlepath", title: "Check for Updates") {
                    updateStatusView
                }
            }
            .buttonStyle(.plain)

            Button(action: openGitHubRepo) {
                SettingsRowView(icon: "star", title: "Star on GitHub") {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                        .foregroundColor(TerminalColors.dimmedText)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var quitSection: some View {
        Button(action: {
            NSApplication.shared.terminate(nil)
        }) {
            HStack {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 13))
                Text("Quit Notchi")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(TerminalColors.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(TerminalColors.red.opacity(0.1))
            .contentShape(Rectangle())
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func saveApiKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        AppSettings.anthropicApiKey = trimmed.isEmpty ? nil : trimmed
    }

    private func openGitHubRepo() {
        NSWorkspace.shared.open(URL(string: "https://github.com/sk-ruban/notchi")!)
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func connectUsage() {
        ClaudeUsageService.shared.connectAndStartPolling()
    }

    private func installHooksIfNeeded() {
        guard !hooksInstalled else { return }
        hooksError = false
        let success = HookInstaller.installIfNeeded()
        if success {
            hooksInstalled = HookInstaller.isInstalled()
        } else {
            hooksError = true
        }
    }

    private func triggerWindowRecreation() {
        NotificationCenter.default.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch updateManager.state {
        case .checking:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("Checking...")
                    .font(.system(size: 10))
                    .foregroundColor(TerminalColors.dimmedText)
            }
        case .upToDate:
            statusBadge("Up to date", color: TerminalColors.green)
        case .found(let version, _):
            statusBadge("v\(version) available", color: TerminalColors.amber)
        case .downloading(let progress):
            HStack(spacing: 4) {
                ProgressView(value: progress)
                    .frame(width: 40)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10))
                    .foregroundColor(TerminalColors.dimmedText)
            }
        case .extracting:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("Installing...")
                    .font(.system(size: 10))
                    .foregroundColor(TerminalColors.dimmedText)
            }
        case .readyToInstall(let version):
            Button(action: { updateManager.downloadAndInstall() }) {
                statusBadge("Install v\(version)", color: TerminalColors.green)
            }
            .buttonStyle(.plain)
        case .installing:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("Installing...")
                    .font(.system(size: 10))
                    .foregroundColor(TerminalColors.dimmedText)
            }
        case .error(let message):
            statusBadge(message, color: TerminalColors.red)
        case .idle:
            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                .font(.system(size: 10))
                .foregroundColor(TerminalColors.dimmedText)
        }
    }
}

struct SettingsRowView<Trailing: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(TerminalColors.secondaryText)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 12))
                .foregroundColor(TerminalColors.primaryText)

            Spacer()

            trailing()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct SegmentedPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [(value: T, label: String)]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isSelected = selection == option.value
                Button(action: { selection = option.value }) {
                    Text(option.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isSelected ? .white : TerminalColors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(isSelected ? Color.accentColor : Color.white.opacity(0.08))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
        .frame(width: 140)
    }
}

struct ToggleSwitch: View {
    let isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? TerminalColors.green : Color.white.opacity(0.15))
                .frame(width: 32, height: 18)

            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
                .padding(2)
        }
        .animation(.easeInOut(duration: 0.15), value: isOn)
    }
}

#Preview {
    PanelSettingsView()
        .frame(width: 402, height: 400)
        .background(Color.black)
}
