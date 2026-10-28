import SwiftUI
import UIKit

/// Native launcher shared by iPhone and iPad. The game/session bridge is unchanged.
struct HomeView: View {
    var onPlay: () -> Void
    @StateObject private var link = GameLink()
    @StateObject private var download = GameFilesDownload()
    @StateObject private var player = PlayerName()
    @StateObject private var head = SkinHead()
    @StateObject private var account = MicrosoftAccount()
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var tab = Destination.play
    private enum Sheet: String, Identifiable { case account, newWorld; var id: String { rawValue } }
    @State private var sheet: Sheet?
    @State private var editingName = false
    @State private var nameDraft = ""
    @State private var nameRejected = false

    enum Destination: String, CaseIterable, Identifiable {
        case play, worlds, servers, packs, settings
        var id: Self { self }
        var title: String { rawValue.capitalized }
        var icon: String {
            switch self {
            case .play: return "play.circle"
            case .worlds: return "square.grid.2x2"
            case .servers: return "network"
            case .packs: return "shippingbox"
            case .settings: return "gearshape"
            }
        }
    }

    init(onPlay: @escaping () -> Void = {}) { self.onPlay = onPlay }

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    List(Destination.allCases, selection: Binding<Destination?>(
                        get: { tab }, set: { if let value = $0 { tab = value } }
                    )) { item in
                        Label(item.title, systemImage: item.icon).tag(item)
                    }
                    .navigationTitle("Horizon")
                    .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 280)
                    .accessibilityIdentifier("launcher-navigation-rail")
                } detail: {
                    NavigationStack { destination(tab) }
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                TabView(selection: $tab) {
                    ForEach(Destination.allCases) { item in
                        NavigationStack { destination(item) }
                            .tabItem { Label(item.title, systemImage: item.icon) }
                            .tag(item)
                    }
                }
            }
        }
        .tint(.blue)
        .sheet(item: Binding<Sheet?>(
            get: { sizeClass == .regular || sheet == .account ? sheet : nil },
            set: { sheet = $0 }
        )) { item in
            switch item {
            case .account: accountSheet
            case .newWorld: newWorldSheet
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { sizeClass != .regular && sheet == .newWorld },
            set: { if !$0 { sheet = nil } }
        )) { newWorldSheet }
        .alert("Offline player name", isPresented: $editingName) {
            TextField("Name", text: $nameDraft).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Save") {
                guard account.profile == nil else { return }
                nameRejected = !player.save(nameDraft.trimmingCharacters(in: .whitespaces))
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Up to 16 characters, with no spaces.") }
        .alert("That name can’t be used", isPresented: $nameRejected) {
            Button("OK", role: .cancel) {}
        } message: { Text("Use 1 to 16 characters with no spaces.") }
        .alert("Something went wrong", isPresented: Binding(
            get: { link.problem != nil }, set: { if !$0 { link.problem = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(link.problem ?? "") }
        .task(id: shownName) { await head.load(shownName) }
        .task(id: account.profile) { await account.handOver() }
        .onChange(of: account.profile) { profile in
            if profile != nil { editingName = false; nameDraft = "" }
        }
        .task { link.uncover = onPlay; await link.watch() }
    }

    private var shownName: String? { account.profile?.name ?? player.name }

    private func editName() {
        guard account.profile == nil else { return }
        nameDraft = player.name ?? ""
        editingName = true
    }

    private func destination(_ item: Destination) -> some View {
        page {
            switch item {
            case .play: home
            case .worlds: WorldsSection(link: link, newWorld: { sheet = .newWorld })
            case .servers: ServersPage(link: link, account: account)
            case .packs: PacksPage(link: link)
            case .settings:
                VStack(spacing: 24) {
                    SettingsPage(link: link, download: download)
                    NavigationLink { page { GalleryPage() }.navigationTitle("Screenshots") } label: {
                        Label("Screenshots", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity, alignment: .leading).padding(16).card()
                    }
                }
            }
        }
        .navigationTitle(item.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { sheet = .account } label: {
                    Avatar(name: shownName, face: head.face, size: 30)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Account: \(shownName ?? "Not signed in")")
                .accessibilityIdentifier("launcher-account-button")
            }
        }
    }

    private func page<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(sizeClass == .regular ? 32 : 20)
                .frame(maxWidth: sizeClass == .regular ? 1200 : 700)
                .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .refreshable { await link.reload() }
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 28) {
            launchPanel
            if needsFiles { GameFilesCard(download: download, missing: true) }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 28) {
                    recentWorlds.frame(minWidth: 520, maxWidth: .infinity)
                    VStack(spacing: 14) {
                        quickLink("Multiplayer", detail: "Your saved servers", icon: "network", destination: .servers)
                        quickLink("Personalize", detail: "Textures & shaders", icon: "square.stack.3d.up", destination: .packs)
                    }.frame(width: 280).padding(.top, 56)
                }
                VStack(alignment: .leading, spacing: 24) {
                    recentWorlds
                    HStack(spacing: 14) {
                        quickLink("Multiplayer", detail: "Saved servers", icon: "network", destination: .servers)
                        quickLink("Personalize", detail: "Packs & shaders", icon: "square.stack.3d.up", destination: .packs)
                    }
                }
            }
        }
    }

    private var launchPanel: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 8) {
                Text("JAVA EDITION · \(link.version)").font(.caption.weight(.semibold)).tracking(1.4)
            }
            .foregroundStyle(.white.opacity(0.9))
            Spacer(minLength: 22)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    Kit.image("horizon-mark").resizable().renderingMode(.template)
                        .scaledToFit().frame(width: 54, height: 54).accessibilityHidden(true)
                    Text("Horizon").font(.system(.largeTitle, design: .rounded).bold())
                }
                .foregroundStyle(.white)
                .padding(.top, 8)
                HStack(spacing: 8) {
                    Avatar(name: shownName, face: head.face, size: 26)
                    Text(shownName ?? "Offline player").font(.subheadline.weight(.medium)).lineLimit(1)
                    if account.profile != nil {
                        Image(systemName: "checkmark.seal.fill").font(.caption)
                            .accessibilityLabel("Microsoft account")
                    }
                }.foregroundStyle(.white.opacity(0.9))
                    .accessibilityIdentifier("launcher-playing-as")
            }
            HStack {
                Button { Task { await link.play() } } label: {
                    Label(playLabel, systemImage: "play.fill")
                        .font(.headline).frame(minWidth: 124, minHeight: 36)
                }
                .controlSize(.large)
                .launcherPrimaryButton()
                .tint(.blue)
                .disabled(needsFiles || link.launching != nil)
                .accessibilityIdentifier("launcher-play-button")
                if link.launching != nil {
                    Button("Cancel") { link.cancelLaunch() }.foregroundStyle(.white).frame(minHeight: 44)
                }
                Spacer(minLength: 0)
            }
            if case let .loading(progress) = link.phase {
                ProgressView(value: progress).tint(.white).accessibilityLabel("Loading game")
            }
        }
        .padding(sizeClass == .regular ? 32 : 24)
        .frame(maxWidth: .infinity, minHeight: sizeClass == .regular ? 350 : 300, alignment: .leading)
        .background {
            LauncherLandscape(index: 0)
                .overlay(LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.72)],
                                        startPoint: .topTrailing, endPoint: .bottomLeading))
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private var recentWorlds: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Jump back in").font(.title3.bold())
                Spacer()
                Button("All Worlds") { tab = .worlds }.font(.subheadline.weight(.medium)).frame(minHeight: 44)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(link.worlds.prefix(4).enumerated()), id: \.element.id) { index, world in
                        Button { Task { await link.play(world) } } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                ZStack(alignment: .bottomLeading) {
                                    LauncherLandscape(index: index + 1, world: world)
                                    LinearGradient(colors: [.clear, .black.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                                    HStack {
                                        Label(world.mode.capitalized, systemImage: world.mode == "creative" ? "cube" : "leaf")
                                            .font(.caption.weight(.medium))
                                        Spacer()
                                        Image(systemName: "play.circle.fill").font(.title2)
                                    }.foregroundStyle(.white).padding(14)
                                }
                                .frame(height: 138).clipShape(RoundedRectangle(cornerRadius: 18))
                                Text(world.name).font(.headline).foregroundStyle(.primary).lineLimit(1)
                                Text(world.lastPlayed, style: .relative).font(.caption).foregroundStyle(.secondary)
                            }.frame(width: sizeClass == .regular ? 260 : 230, alignment: .leading)
                        }
                        .buttonStyle(.plain).disabled(link.launching != nil)
                    }
                    Button { tab = .worlds } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "plus.circle").font(.largeTitle.weight(.light))
                            Text("Explore your worlds").font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                        .frame(width: link.worlds.isEmpty ? 280 : 180, height: 138)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                        .padding(.bottom, 52)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func quickLink(_ title: String, detail: String, icon: String, destination: Destination) -> some View {
        Button { tab = destination } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: icon).font(.title2.weight(.medium))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.blue).background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.headline).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.85)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22))
        }.buttonStyle(.plain)
    }

    private var playLabel: String { link.launching ?? (needsFiles ? "Game files needed" : "Play") }
    private var needsFiles: Bool {
        if case .needsFiles = link.phase { return true }
        return link.phase == .waiting && !GameFolder.hasGameFiles
    }

    private var newWorldSheet: some View {
        NewWorldSheet { settings in
            sheet = nil
            Task { await link.create(settings) }
        }
    }

    private var accountSheet: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        Avatar(name: shownName, face: head.face, size: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(shownName ?? "Offline player").font(.headline)
                            Text(account.profile == nil ? "Offline profile" : "Microsoft account")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 8)
                    if account.profile == nil { Button("Change Offline Name", action: editName) }
                }
                Section { AccountCard(account: account) }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { sheet = nil } } }
        }
        .presentationDetents([.medium, .large])
    }
}

struct Avatar: View {
    let name: String?
    let face: UIImage?
    let size: CGFloat
    var body: some View {
        Group {
            if let face {
                Image(uiImage: face).resizable().interpolation(.none).scaledToFit().padding(size * 0.10)
            } else {
                Image(systemName: "person.fill").resizable().scaledToFit().padding(size * 0.24)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(Theme.surfaceDisabled, in: RoundedRectangle(cornerRadius: size * 0.3))
        .accessibilityHidden(true)
    }
}
