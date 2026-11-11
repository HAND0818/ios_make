import Foundation

enum Lang: String, CaseIterable {
    case ko = "한국어"
    case en = "English"
}

/// 키는 영어 원문. 한국어일 때만 사전에서 찾고, 없으면 원문 그대로 보여줌
enum L10n {
    static let ko: [String: String] = [
        "Music": "음악", "YouTube Music": "YouTube 뮤직", "Now Playing": "지금 재생 중", "Settings": "설정",
        "Playlists": "플레이리스트", "Artists": "아티스트", "Albums": "앨범", "Local Songs": "내 음악",
        "Music Videos": "뮤직비디오", "Music Video": "뮤직비디오", "Cover Flow": "커버 플로우",
        "Search": "검색", "Saved Playlists": "저장한 플레이리스트", "Offline Downloads": "오프라인 다운로드", "Offline MVs": "오프라인 MV",
        "Available after StreamResolver is implemented": "StreamResolver 구현 후 사용 가능",
        "Songs": "곡", "iPod Model": "iPod 모델", "Skin & Theme": "스킨 및 테마", "Wheel Feedback": "휠 피드백",
        "Language": "언어", "Storage & Cache": "저장공간 및 캐시",
        "Import Files…": "파일 가져오기…", "Import MV…": "MV 가져오기…",
        "New Playlist…": "새 플레이리스트…", "New Playlist": "새 플레이리스트", "Rename Playlist": "플레이리스트 이름 변경",
        "Name": "이름", "Save": "저장", "Cancel": "취소",
        "Play All": "전체 재생", "Shuffle": "셔플",
        "Add/Remove Songs…": "곡 추가/제거…", "Add/Remove Songs": "곡 추가/제거", "Add to Playlist": "플레이리스트에 추가",
        "Rename…": "이름 변경…", "Delete Playlist": "플레이리스트 삭제", "(Deleted)": "(삭제됨)", "(Empty)": "(비어 있음)",
        "Nothing is playing": "재생 중인 곡이 없어요", "Nothing playing": "재생 중인 곡 없음", "No albums": "앨범 없음",
        "No lyrics": "가사 없음 (같은 이름의 .lrc 파일을 함께 넣어 주세요)",
        "Housing": "본체 색상", "Display": "디스플레이",
        "Monochrome": "흑백", "Backlight": "백라이트", "Color": "컬러",
        "Haptic": "햅틱", "Click Sound": "클릭음", "On": "켬", "Off": "끔", "MVs": "MV",
        "Wi-Fi Transfer": "Wi-Fi 전송", "Wi-Fi not connected": "Wi-Fi에 연결되어 있지 않아요",
        "Open in a browser": "브라우저에서 열어 주세요",
        "Unknown Artist": "알 수 없는 아티스트", "Unknown Album": "알 수 없는 앨범",
        "White": "화이트", "Black": "블랙", "Silver": "실버", "Blue": "블루", "Pink": "핑크", "Green": "그린",
        "Gold": "골드", "Red": "레드", "Purple": "퍼플", "Orange": "오렌지", "Yellow": "옐로"
    ]
}

/// 한글 MP3 태그/가사 파일 인코딩 복구
enum KoreanFix {
    private static let cp949 = String.Encoding(rawValue:
        CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosKorean.rawValue)))

    static func isHangul(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) }
    }

    /// CP949로 저장된 ID3 태그가 Latin-1/CP1252로 잘못 읽혀 깨진 경우 되돌림
    static func fix(_ s: String) -> String {
        guard !isHangul(s), s.unicodeScalars.contains(where: { $0.value >= 0x80 }),
              let d = s.data(using: .windowsCP1252) ?? s.data(using: .isoLatin1),
              let r = String(data: d, encoding: cp949), isHangul(r) else { return s }
        return r
    }

    /// .lrc 파일: UTF-8 먼저, 실패하면 CP949
    static func decode(_ d: Data) -> String? {
        if let s = String(data: d, encoding: .utf8) { return s }
        return String(data: d, encoding: cp949) ?? String(data: d, encoding: .isoLatin1)
    }
}
