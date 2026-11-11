import SwiftUI
import UniformTypeIdentifiers

enum SongFilter: Hashable { case all, artist(String), album(String) }

enum Screen: Hashable {
    case root, music, youtube, nowPlaying, settings, model, skin, feedback, storage
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
    private func push(_ s: Screen) { stack.append(Node(screen: s)) }
    private func pop() {
        guard stack.count > 1 else { return }
        if top.screen == .mvPlayer { store.stopMV() }
        stack.removeLast()
    }

    var body: some View {
        let spec = store.model.spec
        let h = store.housing
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                lcd(spec)
                ClickWheel(spec: spec, housing: h,
                           step: step, center: center,
                           menu: { store.tick(); pop() },
                           next: { store.tick(); skip(1) },
                           prev: { store.tick(); skip(-1) },
                           playPause: { store.tick(); playPause() })
            }
            .padding(18)
            .frame(width: spec.width)
            .background(RoundedRectangle(cornerRadius: 26).fill(h.body).shadow(radius: 14, y: 8))
        }
        .fileImporter(isPresented: $picker, allowedContentTypes: [.audio, .movie, .plainText], allowsMultipleSelection: true) { r in
            if case .success(let urls) = r { store.importFiles(urls) }
        }
        .alert(nameTarget == nil ? "New Playlist" : "Rename Playlist", isPresented: $showName) {
            TextField("Name", text: $nameText)
            Button("Save") { saveName() }
            Button("Cancel", role: .cancel) {}
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
        case .coverFlow: CoverFlowView(tracks: store.tracks, selected: top.sel, theme: th)
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

    private func nav(_ t: String, _ s: Screen) -> Item { Item(title: t, chevron: true) { push(s) } }

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
        case .music: return "Music"
        case .youtube, .ytStub: return "YouTube Music"
        case .nowPlaying: return "Now Playing"
        case .settings: return "Settings"
        case .model: return "iPod Model"
        case .skin: return "Skin & Theme"
        case .feedback: return "Wheel Feedback"
        case .storage: return "Storage & Cache"
        case .songs: return "Songs"
        case .artists: return "Artists"
        case .albums: return "Albums"
        case .playlists: return "Playlists"
        case .playlist(let id): return store.playlists.first { $0.id == id }?.name ?? "Playlist"
        case .pickSongs: return "Add/Remove Songs"
        case .addToPlaylist: return "Add to Playlist"
        case .mvList: return "Music Videos"
        case .mvPlayer: return "Music Video"
        case .coverFlow: return "Cover Flow"
        }
    }

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
            return [Item(title: "StreamResolver 구현 후 사용 가능") {}]
        case .playlists:
            var out = [Item(title: "+ New Playlist…") { askName(for: nil) }]
            out += store.playlists.map { p in Item(title: p.name, chevron: true) { push(.playlist(p.id)) } }
            return out
        case .playlist(let id):
            guard let p = store.playlists.first(where: { $0.id == id }) else { return [Item(title: "(삭제됨)") {}] }
            let list = store.tracks(of: p)
            var out: [Item] = []
            if !list.isEmpty {
                out.append(Item(title: "▶ Play All") { store.start(list[0], in: list); push(.nowPlaying) })
                out.append(Item(title: "⇄ Shuffle") { let s = list.shuffled(); store.start(s[0], in: s); push(.nowPlaying) })
            }
            out += list.map { t in Item(title: t.title) { store.start(t, in: list); push(.nowPlaying) } }
            out.append(Item(title: "Add/Remove Songs…", chevron: true) { push(.pickSongs(id)) })
            out.append(Item(title: "Rename…") { askName(for: id, text: p.name) })
            out.append(Item(title: "Delete Playlist") { store.deletePlaylist(id); pop() })
            return out
        case .pickSongs(let id):
            guard let p = store.playlists.first(where: { $0.id == id }) else { return [] }
            return store.tracks.map { t in
                Item(title: (p.files.contains(t.url.lastPathComponent) ? "✓ " : "    ") + t.title) { store.toggle(t, in: id) }
            }
        case .addToPlaylist:
            guard let c = store.current, store.tracks.indices.contains(c) else { return [Item(title: "재생 중인 곡이 없어요") {}] }
            let t = store.tracks[c]
            var out = store.playlists.map { p in
                Item(title: (p.files.contains(t.url.lastPathComponent) ? "✓ " : "    ") + p.name) { store.toggle(t, in: p.id) }
            }
            out.append(Item(title: "+ New Playlist…") { askName(for: nil) })
            return out
        case .artists:
            return Set(store.tracks.map(\.artist)).sorted().map { a in nav(a, .songs(.artist(a))) }
        case .albums:
            return Set(store.tracks.map(\.album)).sorted().map { a in nav(a, .songs(.album(a))) }
        case .songs(let f):
            var out: [Item] = []
            if f == .all { out.append(Item(title: "+ Import Files…") { picker = true }) }
            out += filtered(f).map { t in
                Item(title: t.title) {
                    store.start(t, in: filtered(f)); push(.nowPlaying)
                }
            }
            return out
        case .mvList:
            var out = [Item(title: "+ Import MV…") { picker = true }]
            out += store.mvs.enumerated().map { (i, m) in Item(title: m.title) { store.playMV(i); push(.mvPlayer) } }
            return out
        case .settings:
            return [nav("iPod Model", .model), nav("Skin & Theme", .skin), nav("Wheel Feedback", .feedback), nav("Storage & Cache", .storage)]
        case .model:
            return PodModel.allCases.map { m in
                Item(title: (m == store.model ? "✓ " : "") + m.rawValue) {
                    store.model = m; store.housingIndex = 0
                    store.theme = m.spec.color ? .color : .mono
                }
            }
        case .skin:
            let n = store.model.spec.housings.count
            return [Item(title: "Housing: \(store.housing.name)") { store.housingIndex = (store.housingIndex + 1) % n },
                    Item(title: "Display: \(store.theme.rawValue)") { store.theme = store.theme.next }]
        case .feedback:
            return [Item(title: "Haptic: \(store.haptic ? "On" : "Off")") { store.haptic.toggle() },
                    Item(title: "Click Sound: \(store.sound ? "On" : "Off")") { store.sound.toggle() }]
        case .storage:
            return [Item(title: "Songs: \(store.tracks.count)") {}, Item(title: "MVs: \(store.mvs.count)") {}]
        case .nowPlaying, .mvPlayer, .coverFlow:
            return []
        }
    }
}
