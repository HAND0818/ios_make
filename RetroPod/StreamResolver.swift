import Foundation

struct RemoteTrack: Identifiable, Hashable {
    let id: String
    var title: String
    var artist: String
    var thumbnail: URL?
}

/// YouTube / YouTube Music 연동 지점.
/// 실제 구현(YouTube Data API, InnerTube 등)은 여기에 끼워 넣으세요.
/// 비공식 추출 방식은 이용약관 문제와 잦은 API 변경 위험이 있어 분리해 두었습니다.
protocol StreamResolver {
    func search(_ query: String) async throws -> [RemoteTrack]
    func audioURL(for id: String) async throws -> URL
}

/// 다운로드 캐시: 받은 파일을 Documents에 저장하면 로컬 라이브러리가 자동 인식합니다.
enum OfflineCache {
    static func save(_ remote: URL, as name: String) async throws {
        let (tmp, _) = try await URLSession.shared.download(from: remote)
        let dest = PlayerStore.docs.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmp, to: dest)
    }
}
