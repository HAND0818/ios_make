import SwiftUI
import AVFoundation

struct Item {
    let title: String
    var chevron = false
    let action: () -> Void
}

struct CoverArt: View {
    let track: Track?
    var body: some View {
        if let d = track?.artwork, let ui = UIImage(data: d) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else {
            let h = Double((track?.title.unicodeScalars.reduce(0) { $0 + Int($1.value) } ?? 0) % 360) / 360
            ZStack {
                LinearGradient(colors: [Color(hue: h, saturation: 0.7, brightness: 0.85),
                                        Color(hue: (h + 0.17).truncatingRemainder(dividingBy: 1), saturation: 0.7, brightness: 0.45)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note").foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

struct MenuList: View {
    let items: [Item]
    let selected: Int
    let theme: DisplayTheme
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(items.indices, id: \.self) { i in
                        HStack {
                            Text(items[i].title).lineLimit(1)
                            Spacer()
                            if items[i].chevron { Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)) }
                        }
                        .font(.system(size: 14))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .foregroundColor(i == selected ? theme.hiFg : theme.fg)
                        .background(i == selected ? theme.hiBg : Color.clear)
                        .id(i)
                    }
                }
            }
            .onChange(of: selected) { v in proxy.scrollTo(v) }
        }
    }
}

struct NowPlayingView: View {
    @ObservedObject var store: PlayerStore
    let theme: DisplayTheme
    var onAdd: () -> Void = {}

    private func fmt(_ s: Double) -> String {
        let t = Int(max(0, s))
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    var body: some View {
        let t: Track? = store.current.flatMap { store.tracks.indices.contains($0) ? store.tracks[$0] : nil }
        VStack(alignment: .leading, spacing: 6) {
            if store.showLyrics {
                LyricsView(lines: store.lyrics, time: store.time)
            } else {
                HStack(spacing: 10) {
                    CoverArt(track: t).frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 4))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t?.title ?? "Nothing playing").font(.system(size: 14, weight: .bold)).lineLimit(2)
                        Text(t?.artist ?? "")
                        Text(t?.album ?? "")
                    }.font(.system(size: 12))
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
            ProgressView(value: min(store.time, max(store.duration, 1)), total: max(store.duration, 1)).tint(theme.fg)
            HStack {
                Text(fmt(store.time)); Spacer(); Text("-" + fmt(store.duration - store.time))
            }.font(.system(size: 11))
        }
        .padding(8)
        .foregroundColor(theme.fg)
        .contentShape(Rectangle())
        .onTapGesture { store.showLyrics.toggle() }   // 화면을 탭하면 커버 ↔ 가사 전환
        .onLongPressGesture { onAdd() }               // 길게 누르면 플레이리스트에 추가
    }
}

struct LyricsView: View {
    let lines: [LyricLine]
    let time: Double
    var body: some View {
        let idx = lines.lastIndex { $0.time <= time } ?? -1
        VStack(spacing: 4) {
            if lines.isEmpty {
                Text("가사 없음 (같은 이름의 .lrc 파일을 함께 넣어 주세요)").font(.system(size: 12)).multilineTextAlignment(.center)
            } else {
                ForEach([-1, 0, 1], id: \.self) { o in
                    Text(lines.indices.contains(idx + o) ? lines[idx + o].text : " ")
                        .font(.system(size: o == 0 ? 14 : 12, weight: o == 0 ? .bold : .regular))
                        .opacity(o == 0 ? 1 : 0.5)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CoverFlowView: View {
    let tracks: [Track]
    let selected: Int
    let theme: DisplayTheme
    var body: some View {
        ZStack {
            ForEach(tracks.indices, id: \.self) { i in
                let d = i - selected
                if abs(d) < 4 {
                    CoverArt(track: tracks[i])
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .scaleEffect(d == 0 ? 1.15 : 0.85)
                        .rotation3DEffect(.degrees(d == 0 ? 0 : (d > 0 ? -55 : 55)), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                        .offset(x: CGFloat(d) * 42 + (d == 0 ? 0 : CGFloat(d.signum()) * 34), y: -14)
                        .zIndex(Double(10 - abs(d)))
                }
            }
            VStack {
                Spacer()
                Text(tracks.indices.contains(selected) ? tracks[selected].title : "No albums")
                    .font(.system(size: 13)).padding(.bottom, 6)
            }
        }
        .animation(.easeOut(duration: 0.15), value: selected)
        .foregroundColor(theme.fg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

/// 오프라인 MV 재생용 AVPlayerLayer 뷰
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    final class V: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
    }
    func makeUIView(context: Context) -> V {
        let v = V()
        let l = v.layer as! AVPlayerLayer
        l.player = player
        l.videoGravity = .resizeAspect
        return v
    }
    func updateUIView(_ uiView: V, context: Context) {}
}
