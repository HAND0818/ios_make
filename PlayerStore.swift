import AVFoundation
import AudioToolbox
import SwiftUI
import UIKit

final class PlayerStore: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var mvs: [MV] = []
    @Published var current: Int?
    @Published var isPlaying = false
    @Published var time: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Float = 0.6
    @Published var lyrics: [LyricLine] = []
    @Published var showLyrics = false
    @Published var model: PodModel = .classic
    @Published var housingIndex = 0
    @Published var theme: DisplayTheme = .mono
    @Published var haptic = true
    @Published var sound = true
    @Published var playlists: [Playlist] = PlayerStore.loadPlaylists() { didSet { savePlaylists() } }
    @Published var queue: [Track] = []   // 비어 있으면 전체 라이브러리 순서로 재생
    @Published var lang: Lang = PlayerStore.loadLang() { didSet { UserDefaults.standard.set(lang.rawValue, forKey: "lang") } }

    static func loadLang() -> Lang {
        if let r = UserDefaults.standard.string(forKey: "lang"), let l = Lang(rawValue: r) { return l }
        return Locale.current.language.languageCode?.identifier == "ko" ? .ko : .en
    }

    /// UI 문자열 번역 (사전에 없으면 원문 그대로)
    func t(_ key: String) -> String { lang == .ko ? (L10n.ko[key] ?? key) : key }

    let player = AVPlayer()
    let mvPlayer = AVPlayer()
    private let impact = UIImpactFeedbackGenerator(style: .light)

    static let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    static let audioExt: Set<String> = ["mp3", "flac", "m4a", "aac", "wav", "aiff"]
    static let videoExt: Set<String> = ["mp4", "mov", "m4v"]

    var housing: Housing {
        let h = model.spec.housings
        return h[housingIndex % h.count]
    }

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.volume = volume
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] t in
            guard let self, t.seconds.isFinite else { return }
            self.time = t.seconds
        }
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] n in
            guard let self, (n.object as? AVPlayerItem) === self.player.currentItem else { return }
            self.next()
        }
        refreshLibrary()
    }

    // MARK: 라이브러리

    func importFiles(_ urls: [URL]) {
        for u in urls {
            let ok = u.startAccessingSecurityScopedResource()
            defer { if ok { u.stopAccessingSecurityScopedResource() } }
            let dest = Self.docs.appendingPathComponent(u.lastPathComponent)
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: u, to: dest)
        }
        refreshLibrary()
    }

    func refreshLibrary() {
        Task {
            let files = (try? FileManager.default.contentsOfDirectory(at: Self.docs, includingPropertiesForKeys: nil)) ?? []
            var t: [Track] = []
            var v: [MV] = []
            for f in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let e = f.pathExtension.lowercased()
                if Self.audioExt.contains(e) { t.append(await Self.makeTrack(f)) }
                else if Self.videoExt.contains(e) { v.append(MV(url: f, title: f.deletingPathExtension().lastPathComponent)) }
            }
            await MainActor.run { self.tracks = t; self.mvs = v }
        }
    }

    /// ID3/메타데이터에서 제목, 아티스트, 앨범, 커버 추출
    static func makeTrack(_ url: URL) async -> Track {
        let asset = AVURLAsset(url: url)
        let items = (try? await asset.load(.commonMetadata)) ?? []
        func text(_ id: AVMetadataIdentifier) async -> String? {
            guard let it = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: id).first else { return nil }
            return try? await it.load(.stringValue)
        }
        var art: Data?
        if let it = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: .commonIdentifierArtwork).first {
            art = try? await it.load(.dataValue)
        }
        let title = await text(.commonIdentifierTitle).map(KoreanFix.fix)
        let artist = await text(.commonIdentifierArtist).map(KoreanFix.fix)
        let album = await text(.commonIdentifierAlbumName).map(KoreanFix.fix)
        return Track(url: url,
                     title: title ?? url.deletingPathExtension().lastPathComponent,
                     artist: artist ?? "Unknown Artist",
                     album: album ?? "Unknown Album",
                     artwork: art)
    }

    // MARK: 음악 재생

    func play(_ i: Int) {
        guard tracks.indices.contains(i) else { return }
        mvPlayer.pause()
        current = i; time = 0; duration = 0; lyrics = []
        let item = AVPlayerItem(url: tracks[i].url)
        player.replaceCurrentItem(with: item)
        player.volume = volume
        player.play()
        isPlaying = true
        let track = tracks[i]
        Task {
            let d = (try? await item.asset.load(.duration).seconds) ?? 0
            await MainActor.run { if self.current == i { self.duration = d.isFinite ? d : 0 } }
            await loadLyrics(for: track, index: i, duration: d.isFinite ? d : 0)
        }
    }

    func togglePlay() {
        if current == nil { play(0); return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }

    /// 선택한 목록(플레이리스트, 아티스트 등)을 재생 대기열로 삼아 재생
    func start(_ t: Track, in list: [Track]) {
        queue = list
        if let i = tracks.firstIndex(where: { $0.url == t.url }) { play(i) }
    }

    private func step(_ d: Int) {
        let list = queue.isEmpty ? tracks : queue
        guard let c = current, tracks.indices.contains(c), !list.isEmpty else { return }
        let pos = list.firstIndex { $0.url == tracks[c].url } ?? 0
        let t = list[(pos + d + list.count) % list.count]
        if let i = tracks.firstIndex(where: { $0.url == t.url }) { play(i) }
    }

    func next() { step(1) }

    func prev() {
        if time > 3 { player.seek(to: .zero) } else { step(-1) }
    }

    func adjustVolume(_ d: Int) {
        volume = min(1, max(0, volume + Float(d) * 0.04))
        player.volume = volume
        mvPlayer.volume = volume
    }

    // MARK: 가사 (같은 이름의 .lrc → 내장 가사 → LRCLIB 순서)

    private func loadLyrics(for t: Track, index i: Int, duration: Double) async {
        var result: [LyricLine] = []
        let side = t.url.deletingPathExtension().appendingPathExtension("lrc")
        if let d = try? Data(contentsOf: side), let s = KoreanFix.decode(d) { result = LRC.parse(s) }
        if result.isEmpty, let raw = try? await AVURLAsset(url: t.url).load(.lyrics), !raw.isEmpty {
            let s = KoreanFix.fix(raw)
            let p = LRC.parse(s)
            result = p.isEmpty ? LRC.plain(s, duration: duration) : p
        }
        if result.isEmpty, let s = await LRCLIB.synced(title: t.title, artist: t.artist, duration: duration) {
            result = LRC.parse(s)
        }
        await MainActor.run { if self.current == i { self.lyrics = result } }
    }

    // MARK: MV (오프라인 영상)

    func playMV(_ i: Int) {
        guard mvs.indices.contains(i) else { return }
        player.pause(); isPlaying = false
        mvPlayer.replaceCurrentItem(with: AVPlayerItem(url: mvs[i].url))
        mvPlayer.volume = volume
        mvPlayer.play()
    }

    func stopMV() {
        mvPlayer.pause()
        mvPlayer.replaceCurrentItem(with: nil)
    }

    func toggleMV() {
        if mvPlayer.timeControlStatus == .paused { mvPlayer.play() } else { mvPlayer.pause() }
    }

    func seekMV(_ d: Double) {
        let t = max(0, mvPlayer.currentTime().seconds + d)
        mvPlayer.seek(to: CMTime(seconds: t, preferredTimescale: 600))
    }

    // MARK: 플레이리스트

    private static var plURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("playlists.json")
    }

    static func loadPlaylists() -> [Playlist] {
        guard let d = try? Data(contentsOf: plURL),
              let p = try? JSONDecoder().decode([Playlist].self, from: d) else { return [] }
        return p
    }

    private func savePlaylists() {
        let url = Self.plURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(playlists) { try? d.write(to: url, options: .atomic) }
    }

    @discardableResult
    func createPlaylist(_ name: String) -> UUID {
        let p = Playlist(name: name, files: [])
        playlists.append(p)
        return p.id
    }

    func renamePlaylist(_ id: UUID, _ name: String) {
        if let i = playlists.firstIndex(where: { $0.id == id }) { playlists[i].name = name }
    }

    func deletePlaylist(_ id: UUID) { playlists.removeAll { $0.id == id } }

    /// 곡이 이미 들어 있으면 빼고, 없으면 추가
    func toggle(_ t: Track, in id: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == id }) else { return }
        let f = t.url.lastPathComponent
        if let k = playlists[i].files.firstIndex(of: f) { playlists[i].files.remove(at: k) }
        else { playlists[i].files.append(f) }
    }

    func tracks(of p: Playlist) -> [Track] {
        p.files.compactMap { f in tracks.first { $0.url.lastPathComponent == f } }
    }

    // MARK: 휠 피드백

    func tick() {
        if haptic { impact.impactOccurred() }
        if sound { AudioServicesPlaySystemSound(1104) }
    }
}
