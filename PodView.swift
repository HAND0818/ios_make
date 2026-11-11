import SwiftUI
import UniformTypeIdentifiers

enum SongFilter: Hashable { case all, artist(String), album(String) }

enum Screen: Hashable {
    case root, music, youtube, nowPlaying, settings, model, skin, feedback, storage, language
    case songs(SongFilter), artists, albums, playlists, mvList, mvPlayer, coverFlow, ytStub
    case playlist(UUID), pickSongs(UUID), addToPlaylist
}

struct Node {
    var screen: Screen
    var sel = 0
}

struct PodView: View {
    @StateObject private var store = PlayerStore()
    @State private var stack = [Node(screen: .root)]
    @State private var picker = false
    @State private var showName = false
    @State private var nameText = ""
    @State private var nameTarget: UUID?   // nil이면 새 플레이리스트

    private var top: Node { stack[stack.count - 1] }
    private func t(_ k: String) -> String { store.t(k) }
    private func push(_ s: Screen) { stack.append(Node(screen: s)) }
    private func pop() {
        guard stack.count > 1 else { return }
        if top.screen == .mvPlayer { store.stopMV() }
        stack.removeLast()
    }

    // MARK: 화면 구성 (아이폰 17: 402×874pt 전체 화면 기준, 본체가 화면을 가득 채움)

    var body: some View {
        let spec = store.model.spec
        let h = store.housing
        GeometryReader { geo in
            let dw = spec.width - 36                                   // 설계 기준 LCD 폭
            let wheelH = spec.wheel + (spec.layout == .row ? 48 : 0)   // 3세대는 버튼 줄 포함
            let scale = max(0.5, min((geo.size.width - 40) / dw,
                                     (geo.size.height - 40) / (spec.lcd + 24 + wheelH)))
            VStack(spacing: 0) {
                lcd(spec)
                    .frame(width: dw, height: spec.lcd)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: dw * scale, height: spec.lcd * scale, alignment: .topLeading)
                Spacer(minLength: 16)
                ClickWheel(spec: spec, housing: h,
                           step: step, center: center,
                           menu: { store.tick(); pop() },
                           next: { store.tick(); skip(1) },
                           prev: { store.tick(); skip(-1) },
                           playPause: { store.tick(); playPause() })
                    .fixedSize()
                    .scaleEffect(scale, anchor: .top)
                    .frame(width: spec.wheel * scale, height: wheelH * scale, alignment: .top)
            }
            .padding(.vertical, 20)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(h.body.ignoresSafeArea())
        .preferredColorScheme(h.name == "Black" ? .dark : .light)
        .fileImporter(isPresented: $picker, allowedContentTypes: [.audio, .movie, .plainText], allowsMultipleSelection: true) { r in
            if case .success(let urls) = r { store.importFiles(urls) }
        }
        .alert(t(nameTarget == nil ? "New Playlist" : "Rename Playlist"), isPresented: $showName) {
            TextField(t("Name"), text: $nameText)
            Button(t("Save")) { saveName() }
            Button(t("Cancel"), role: .cancel) {}
        }
    }

    private func askName(for id: UUID?, text: String = "") {
        nameTarget = id
        nameText = text
        showName = true
    }

    private func saveName() {
        let n = nameText.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        if let id = nameTarget {
            store.renamePlaylist(id, n)
        } else {
            let id = store.createPlaylist(n)
            // '플레이리스트에 추가' 화면에서 만들면 재생 중인 곡도 바로 담김
            if top.screen == .addToPlaylist, let c = store.current, store.tracks.indices.contains(c) {
                store.toggle(store.tracks[c], in: id)
            }
        }
    }

    // MARK: LCD

    private func lcd(_ spec: PodModel.Spec) -> some View {
        let th = store.theme
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(title(top.screen)).lineLimit(1)
                Spacer()
                Image(systemName: store.isPlaying ? "play.fill" : "pause.fill").font(.system(size: 9))
                Image(systemName: "battery.100").font(.system(size: 11))
            }
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundColor(th.fg)
            Rectangle().fill(th.fg).frame(height: 1)
            content(th)
        }
        .frame(height: spec.lcd)
        .background(th.bg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 3))
    }

    @ViewBuilder private func content(_ th: DisplayTheme) -> some View {
        switch top.screen {
        case .nowPlaying: NowPlayingView(store: store, theme: th, onAdd: { push(.addToPlaylist) })
        case .mvPlayer: PlayerLayerView(player: store.mvPlayer).background(Color.black)
        case .coverFlow: CoverFlowView(tracks: store.tracks, selected: top.sel, theme: th, empty: t("No albums"))
        default: MenuList(items: items(top.screen), selected: top.sel, theme: th)
        }
    }

    // MARK: 입력 처리

    private func move(_ d: Int, count: Int) {
        guard count > 0 else { return }
        stack[stack.count - 1].sel = min(count - 1, max(0, top.sel + d))
    }

    private func step(_ d: Int) {
        store.tick()
        switch top.screen {
        case .nowPlaying, .mvPlayer: store.adjustVolume(d)
        case .coverFlow: move(d, count: store.tracks.count)
        default: move(d, count: items(top.screen).count)
        }
    }

    private func center() {
        store.tick()
        switch top.screen {
        case .nowPlaying: store.togglePlay()
        case .mvPlayer: store.toggleMV()
        case .coverFlow:
            if store.tracks.indices.contains(top.sel) { store.start(store.tracks[top.sel], in: store.tracks); push(.nowPlaying) }
        default:
            let its = items(top.screen)
            if its.indices.contains(top.sel) { its[top.sel].action() }
        }
    }

    private func skip(_ d: Int) {
        if top.screen == .mvPlayer { store.seekMV(Double(d) * 10) }
        else if d > 0 { store.next() } else { store.prev() }
    }

    private func playPause() {
        if top.screen == .mvPlayer { store.toggleMV() } else { store.togglePlay() }
    }

    // MARK: 메뉴 구조

    private func nav(_ key: String, _ s: Screen) -> Item { Item(title: t(key), chevron: true) { push(s) } }

    private func filtered(_ f: SongFilter) -> [Track] {
        switch f {
        case .all: return store.tracks
        case .artist(let a): return store.tracks.filter { $0.artist == a }
        case .album(let a): return store.tracks.filter { $0.album == a }
        }
    }

    private func title(_ s: Screen) -> String {
        switch s {
        case .root: return "RetroPod"
        case .music: return t("Music")
        case .youtube, .ytStub: return t("YouTube Music")
        case .nowPlaying: return t("Now Playing")
        case .settings: return t("Settings")
        case .model: return t("iPod Model")
        case .skin: return t("Skin & Theme")
        case .feedback: return t("Wheel Feedback")
        case .storage: return t("Storage & Cache")
        case .language: return t("Language")
        case .songs: return t("Songs")
        case .artists: return t("Artists")
        case .albums: return t("Albums")
        case .playlists: return t("Playlists")
        case .playlist(let id): return store.playlists.first { $0.id == id }?.name ?? t("Playlists")
        case .pickSongs: return t("Add/Remove Songs")
        case .addToPlaylist: return t("Add to Playlist")
        case .mvList: return t("Music Videos")
        case .mvPlayer: return t("Music Video")
        case .coverFlow: return t("Cover Flow")
        }
    }

    private func onOff(_ b: Bool) -> String { t(b ? "On" : "Off") }

    private func items(_ s: Screen) -> [Item] {
        switch s {
        case .root:
            return [nav("Music", .music), nav("YouTube Music", .youtube), nav("Now Playing", .nowPlaying), nav("Settings", .settings)]
        case .music:
            return [nav("Playlists", .playlists), nav("Artists", .artists), nav("Albums", .albums),
                    nav("Local Songs", .songs(.all)), nav("Music Videos", .mvList), nav("Cover Flow", .coverFlow)]
        case .youtube:
            return [nav("Search", .ytStub), nav("Saved Playlists", .ytStub),
                    nav("Offline Downloads", .songs(.all)), nav("Offline MVs", .mvList)]
        case .ytStub:
            return [Item(title: t("Available after StreamResolver is implemented")) {}]
        case .playlists:
            var out = [Item(title: t("New Playlist…"), icon: "plus") { askName(for: nil) }]
            out += store.playlists.map { p in Item(title: p.name, chevron: true) { push(.playlist(p.id)) } }
            return out
        case .playlist(let id):
            guard let p = store.playlists.first(where: { $0.id == id }) else { return [Item(title: t("(Deleted)")) {}] }
            let list = store.tracks(of: p)
            var out: [Item] = []
            if !list.isEmpty {
                out.append(Item(title: t("Play All"), icon: "play.fill") { store.start(list[0], in: list); push(.nowPlaying) })
                out.append(Item(title: t("Shuffle"), icon: "shuffle") { let s = list.shuffled(); store.start(s[0], in: s); push(.nowPlaying) })
            }
            out += list.map { tr in Item(title: tr.title) { store.start(tr, in: list); push(.nowPlaying) } }
            out.append(Item(title: t("Add/Remove Songs…"), chevron: true) { push(.pickSongs(id)) })
            out.append(Item(title: t("Rename…"), icon: "pencil") { askName(for: id, text: p.name) })
            out.append(Item(title: t("Delete Playlist"), icon: "trash") { store.deletePlaylist(id); pop() })
            return out
        case .pickSongs(let id):
            guard let p = store.playlists.first(where: { $0.id == id }) else { return [] }
            return store.tracks.map { tr in
                Item(title: tr.title, check: p.files.contains(tr.url.lastPathComponent)) { store.toggle(tr, in: id) }
            }
        case .addToPlaylist:
            guard let c = store.current, store.tracks.indices.contains(c) else { return [Item(title: t("Nothing is playing")) {}] }
            let tr = store.tracks[c]
            var out = store.playlists.map { p in
                Item(title: p.name, check: p.files.contains(tr.url.lastPathComponent)) { store.toggle(tr, in: p.id) }
            }
            out.append(Item(title: t("New Playlist…"), icon: "plus") { askName(for: nil) })
            return out
        case .artists:
            return Set(store.tracks.map(\.artist)).sorted().map { a in
                Item(title: t(a), chevron: true) { push(.songs(.artist(a))) }
            }
        case .albums:
            return Set(store.tracks.map(\.album)).sorted().map { a in
                Item(title: t(a), chevron: true) { push(.songs(.album(a))) }
            }
        case .songs(let f):
            var out: [Item] = []
            if f == .all { out.append(Item(title: t("Import Files…"), icon: "plus") { picker = true }) }
            out += filtered(f).map { tr in
                Item(title: tr.title) { store.start(tr, in: filtered(f)); push(.nowPlaying) }
            }
            return out
        case .mvList:
            var out = [Item(title: t("Import MV…"), icon: "plus") { picker = true }]
            out += store.mvs.enumerated().map { (i, m) in Item(title: m.title, icon: "film") { store.playMV(i); push(.mvPlayer) } }
            return out
        case .settings:
            return [nav("iPod Model", .model), nav("Skin & Theme", .skin), nav("Wheel Feedback", .feedback),
                    nav("Language", .language), nav("Storage & Cache", .storage)]
        case .model:
            return PodModel.allCases.map { m in
                Item(title: m.rawValue, check: m == store.model) {
                    store.model = m; store.housingIndex = 0
                    store.theme = m.spec.color ? .color : .mono
                }
            }
        case .skin:
            let n = store.model.spec.housings.count
            return [Item(title: "\(t("Housing")): \(t(store.housing.name))") { store.housingIndex = (store.housingIndex + 1) % n },
                    Item(title: "\(t("Display")): \(t(store.theme.rawValue))") { store.theme = store.theme.next }]
        case .feedback:
            return [Item(title: "\(t("Haptic")): \(onOff(store.haptic))") { store.haptic.toggle() },
                    Item(title: "\(t("Click Sound")): \(onOff(store.sound))") { store.sound.toggle() }]
        case .language:
            return Lang.allCases.map { l in Item(title: l.rawValue, check: l == store.lang) { store.lang = l } }
        case .storage:
            return [Item(title: "\(t("Songs")): \(store.tracks.count)") {}, Item(title: "\(t("MVs")): \(store.mvs.count)") {}]
        case .nowPlaying, .mvPlayer, .coverFlow:
            return []
        }
    }
}
