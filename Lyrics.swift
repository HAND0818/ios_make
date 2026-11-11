import Foundation

struct LyricLine: Hashable {
    var time: Double
    var text: String
}

enum LRC {
    /// [mm:ss.xx] 형식의 타임라인 가사 파싱
    static func parse(_ s: String) -> [LyricLine] {
        let re = try! NSRegularExpression(pattern: #"\[(\d+):(\d+(?:\.\d+)?)\]"#)
        var out: [LyricLine] = []
        for raw in s.components(separatedBy: .newlines) {
            let ns = raw as NSString
            let ms = re.matches(in: raw, range: NSRange(location: 0, length: ns.length))
            guard let last = ms.last else { continue }
            let text = ns.substring(from: last.range.location + last.range.length).trimmingCharacters(in: .whitespaces)
            for m in ms {
                let mm = Double(ns.substring(with: m.range(at: 1))) ?? 0
                let ss = Double(ns.substring(with: m.range(at: 2))) ?? 0
                out.append(LyricLine(time: mm * 60 + ss, text: text))
            }
        }
        return out.sorted { $0.time < $1.time }
    }

    /// 시간 정보가 없는 내장 가사는 곡 길이에 맞춰 균등 배분
    static func plain(_ s: String, duration: Double) -> [LyricLine] {
        let lines = s.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !lines.isEmpty else { return [] }
        let step = max(duration, Double(lines.count)) / Double(lines.count)
        return lines.enumerated().map { LyricLine(time: Double($0.offset) * step, text: $0.element) }
    }
}

enum LRCLIB {
    static func synced(title: String, artist: String, duration: Double) async -> String? {
        var c = URLComponents(string: "https://lrclib.net/api/get")!
        c.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "duration", value: String(Int(duration)))
        ]
        guard let url = c.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["syncedLyrics"] as? String
    }
}
