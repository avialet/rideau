import RideauCore
import SwiftUI
import VialetKit

/// Fenetre principale "Scene" : barre laterale (marque, etat, raccourci), puis la carte d'etat et ce que
/// le rideau cache (fenetres, toujours visibles, bureau, notifications).
struct SceneWindow: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 200)
                .background(Theme.sidebar)
            VStack(spacing: 0) {
                UpdateNotice(updater: .shared)
                // Le rendu par calques du mode capture ne dessine pas un ScrollView (limite connue du kit) :
                // contenu pose tel quel pendant la capture.
                if state.isCapture {
                    content.frame(maxHeight: .infinity, alignment: .top)
                } else {
                    ScrollView { content }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AmbientBackground())
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            StageCard()
            SectionHeader("Ce que le rideau cache")
                .padding(.top, Theme.Space.s)
            Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                GridRow(alignment: .top) {
                    WindowsCard()
                    AlwaysVisibleCard()
                }
                GridRow(alignment: .top) {
                    DesktopCard()
                    NotificationsCard()
                }
            }
        }
        .padding(Theme.Space.xxl)
    }

    private var sidebar: some View {
        let down = state.curtain.isDown
        return VStack(alignment: .leading, spacing: 0) {
            Wordmark(Brand.displayName)
                .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 14)
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(down ? Theme.accent : Theme.inkFaint)
                        .frame(width: 8, height: 8)
                    Text(down ? "Rideau baiss\u{00E9}" : "Rideau lev\u{00E9}")
                        .font(Theme.ui(13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                Text("Un appui cache le d\u{00E9}sordre, un second remet tout comme avant.")
                    .font(Theme.ui(12))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader("Automatiser")
                Text(verbatim: "rideau://baisser\nrideau://lever")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.inkSoft)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 18).padding(.bottom, 14)
            ShortcutFooter(HotKeyController.shared.shortcut)
        }
    }
}

// MARK: - Carte d'etat

/// Grande carte : plaque du rideau (ouvert ou ferme), etat, apps concernees, bouton principal.
struct StageCard: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let curtain = state.curtain
        let down = curtain.isDown
        let apps = down ? (curtain.backstage?.hidden ?? []) : curtain.preview
        HStack(alignment: .top, spacing: Theme.Space.xl) {
            Image(nsImage: GlyphImage.plate(Brand.palette, glyph: down ? Brand.loweredGlyph : Brand.glyph, pixels: 160))
                .resizable()
                .frame(width: 68, height: 68)
                .shadow(color: Theme.accent.opacity(0.25), radius: 10, y: 4)
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title(curtain))
                        .font(Theme.display(24))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle(curtain, count: apps.count))
                        .font(Theme.ui(13))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !apps.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(apps, id: \.pid) { app in AppChip(app: app, icon: curtain.hider.icon(for: app)) }
                    }
                }
                notes(curtain, down: down)
                HStack(spacing: Theme.Space.m) {
                    PrimaryButton(down ? "Lever le rideau" : "Baisser le rideau") { curtain.toggle() }
                        .disabled(curtain.state == .lowering || curtain.state == .raising)
                    KeyHint(HotKeyController.shared.shortcut.display, down ? "lever" : "baisser")
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
    }

    private func title(_ curtain: CurtainController) -> String {
        if curtain.machine.recovered { return "Le rideau est rest\u{00E9} baiss\u{00E9}" }
        return curtain.isDown ? "Le rideau est baiss\u{00E9}" : "Le rideau est lev\u{00E9}"
    }

    private func subtitle(_ curtain: CurtainController, count: Int) -> String {
        if curtain.machine.recovered {
            return "Rideau s\u{2019}est arr\u{00EA}t\u{00E9} sans le lever. \(Wording.backstage(count)), pr\u{00EA}tes \u{00E0} revenir \u{00E0} l\u{2019}identique."
        }
        if curtain.isDown {
            let since = curtain.backstage?.loweredAt.formatted(date: .omitted, time: .shortened) ?? ""
            return "Depuis \(since) \u{00B7} \(Wording.backstage(count)). Elles reviendront dans le m\u{00EA}me ordre."
        }
        return Wording.preview(count) + (state.settings.keepFrontmost ? ". L\u{2019}app au premier plan reste devant." : ".")
    }

    @ViewBuilder private func notes(_ curtain: CurtainController, down: Bool) -> some View {
        let refused = down ? (curtain.backstage?.refused ?? []) : []
        let fullScreen = down ? [] : curtain.fullScreenKept.map(\.name)
        if !refused.isEmpty {
            Label("Refus de se masquer : \(refused.joined(separator: ", "))", systemImage: "exclamationmark.triangle")
                .font(Theme.ui(12)).foregroundStyle(Theme.coral)
        }
        if !fullScreen.isEmpty {
            Label("Laiss\u{00E9}es en plein \u{00E9}cran : \(fullScreen.joined(separator: ", "))", systemImage: "arrow.up.left.and.arrow.down.right")
                .font(Theme.ui(12)).foregroundStyle(Theme.inkSoft)
        }
    }
}

/// Icone et nom d'une app.
struct AppChip: View {
    let app: AppSnapshot
    let icon: NSImage?

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(nsImage: icon).resizable().frame(width: 18, height: 18)
            }
            Text(app.name)
                .font(Theme.ui(12, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
        }
        .padding(.leading, icon == nil ? 9 : 5).padding(.trailing, 9).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous).fill(Theme.ink.opacity(0.05)))
    }
}

/// Bouton principal aux teintes de l'app (fond deep et texte blanc en clair, l'inverse en sombre).
struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.ui(13.5, weight: .semibold))
                .foregroundStyle(Theme.accentPrimaryButtonForeground)
                .padding(.horizontal, 18).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                    .fill(Theme.accentPrimaryButtonBackground))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ce que le rideau cache

struct WindowsCard: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var settings = state.settings
        SettingsCard(icon: "macwindow.on.rectangle", color: Theme.accent, title: "Fen\u{00EA}tres") {
            Text("Seules les apps masqu\u{00E9}es par Rideau reviennent, dans leur ordre.")
                .font(Theme.ui(12)).foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Garder l\u{2019}app au premier plan", isOn: $settings.keepFrontmost)
            Toggle("Laisser les apps en plein \u{00E9}cran", isOn: $settings.keepFullScreen)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .font(Theme.ui(13))
        .onChange(of: settings.keepFrontmost) { state.curtain.refreshPreview() }
        .onChange(of: settings.keepFullScreen) { state.curtain.refreshPreview() }
    }
}

struct AlwaysVisibleCard: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let settings = state.settings
        SettingsCard(icon: "video.fill", color: Theme.pine, title: "Toujours visibles") {
            FlowLayout(spacing: 6) {
                ForEach(settings.alwaysVisible.filter(AppState.isAvailable), id: \.self) { id in
                    HStack(spacing: 4) {
                        Text(AppState.appName(id))
                            .font(Theme.ui(12, weight: .medium))
                            .foregroundStyle(Theme.ink)
                        Button {
                            settings.removeAlwaysVisible(id)
                            state.curtain.refreshPreview()
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 8.5, weight: .bold)).foregroundStyle(Theme.inkSoft)
                        }
                        .buttonStyle(.plain)
                        .help("Retirer")
                    }
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous).fill(Theme.ink.opacity(0.05)))
                }
            }
            Menu("Ajouter une app") {
                let candidates = state.curtain.hider.runningApps()
                    .filter { $0.isRegular && $0.bundleID != nil && !settings.alwaysVisible.contains($0.bundleID!) }
                    .filter { !CurtainPolicy.neverHidden.contains($0.bundleID!) }
                    .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                if candidates.isEmpty { Text("Aucune autre app ouverte") }
                ForEach(candidates, id: \.pid) { app in
                    Button(app.name) {
                        settings.addAlwaysVisible(app.bundleID!)
                        state.curtain.refreshPreview()
                    }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .font(Theme.ui(12, weight: .semibold))
            Text("Zoom, Teams, Webex et FaceTime y sont d\u{2019}office : on pr\u{00E9}sente depuis elles.")
                .font(Theme.ui(12)).foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct DesktopCard: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var settings = state.settings
        SettingsCard(icon: "menubar.dock.rectangle", color: Theme.sea, title: "Bureau") {
            Toggle("Couvrir les ic\u{00F4}nes et les widgets", isOn: $settings.coverDesktop)
                .toggleStyle(.switch).controlSize(.small)
            Picker("", selection: $settings.coverStyle) {
                ForEach(CoverStyle.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(!settings.coverDesktop)
            if settings.coverStyle == .color {
                HStack(spacing: 8) {
                    ForEach(CurtainSettings.swatches, id: \.hex) { swatch in
                        Button { settings.coverColor = swatch.hex } label: {
                            Circle()
                                .fill(Color(hex: swatch.hex))
                                .frame(width: 20, height: 20)
                                .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1))
                                .padding(3)
                                .overlay(Circle().strokeBorder(settings.coverColor == swatch.hex ? Theme.accent : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                        .help(swatch.name)
                    }
                }
                .disabled(!settings.coverDesktop)
            }
            Text(settings.coverStyle == .wallpaper
                 ? "Chaque \u{00E9}cran garde son fond d\u{2019}\u{00E9}cran, sans les ic\u{00F4}nes. Couleur unie si macOS ne le fournit pas."
                 : "Une couleur unie recouvre le bureau de chaque \u{00E9}cran.")
                .font(Theme.ui(12)).foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(Theme.ui(13))
    }
}

struct NotificationsCard: View {
    var body: some View {
        SettingsCard(icon: "bell.slash.fill", color: Theme.coral, title: "Notifications") {
            Text("macOS coupe les banni\u{00E8}res pendant un partage d\u{2019}\u{00E9}cran si l\u{2019}option \u{00AB} Autoriser les notifications lors de la recopie ou du partage de l\u{2019}\u{00E9}cran \u{00BB} est d\u{00E9}sactiv\u{00E9}e.")
                .font(Theme.ui(12)).foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Button("Ouvrir les r\u{00E9}glages Notifications") { AppState.openNotificationSettings() }
                .buttonStyle(.link)
                .font(Theme.ui(12, weight: .semibold))
        }
    }
}
