import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255)
    }
}

struct Track: Identifiable, Hashable {
    let id = UUID()
    var url: URL
    var title: String
    var artist: String
    var album: String
    var artwork: Data?
}

struct MV: Identifiable, Hashable {
    let id = UUID()
    var url: URL
    var title: String
}

/// 파일명으로 곡을 가리켜서 앱을 다시 켜도 유지됨
struct Playlist: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var files: [String]
}

struct Housing {
    let name: String
    let body: Color
    let wheel: Color
    let label: Color
    static let white = Housing(name: "White", body: Color(hex: 0xECEAE4), wheel: Color(hex: 0xFAFAF8), label: Color(hex: 0x888888))
    static let black = Housing(name: "Black", body: Color(hex: 0x1C1C1E), wheel: Color(hex: 0x2D2D30), label: Color(hex: 0xAAAAAA))
    static let silver = Housing(name: "Silver", body: Color(hex: 0xC5C7CB), wheel: Color(hex: 0xE6E7EA), label: Color(hex: 0x777777))
    static let blue = Housing(name: "Blue", body: Color(hex: 0x8FB8E8), wheel: Color(hex: 0xE8F0FA), label: Color(hex: 0x666688))
    static let pink = Housing(name: "Pink", body: Color(hex: 0xF0A8C0), wheel: Color(hex: 0xFBE9F0), label: Color(hex: 0xBB6666))
    static let green = Housing(name: "Green", body: Color(hex: 0x9ED39A), wheel: Color(hex: 0xEAF6E8), label: Color(hex: 0x668866))
    static let gold = Housing(name: "Gold", body: Color(hex: 0xE3C98A), wheel: Color(hex: 0xF7EFD9), label: Color(hex: 0xAA8855))
    static let red = Housing(name: "Red", body: Color(hex: 0xC8282E), wheel: Color(hex: 0xE8D8D8), label: Color(hex: 0xAA3333))
    static let purple = Housing(name: "Purple", body: Color(hex: 0xA58AD6), wheel: Color(hex: 0xEEE8F8), label: Color(hex: 0x8866BB))
    static let orange = Housing(name: "Orange", body: Color(hex: 0xF0A040), wheel: Color(hex: 0xFBEFDC), label: Color(hex: 0xCC8800))
    static let yellow = Housing(name: "Yellow", body: Color(hex: 0xF0D848), wheel: Color(hex: 0xFBF6D8), label: Color(hex: 0xAA9900))
}

enum DisplayTheme: String, CaseIterable {
    case mono = "Monochrome", backlight = "Backlight", color = "Color"
    var bg: Color {
        switch self {
        case .mono: return Color(hex: 0xC9D3B4)
        case .backlight: return Color(hex: 0x9FD8EA)
        case .color: return .white
        }
    }
    var fg: Color {
        switch self {
        case .mono: return Color(hex: 0x1D2316)
        case .backlight: return Color(hex: 0x06222C)
        case .color: return .black
        }
    }
    var hiBg: Color {
        switch self {
        case .mono: return Color(hex: 0x1D2316)
        case .backlight: return Color(hex: 0x06222C)
        case .color: return Color(hex: 0x2F7BF0)
        }
    }
    var hiFg: Color {
        switch self {
        case .mono: return Color(hex: 0xC9D3B4)
        case .backlight: return Color(hex: 0x9FD8EA)
        case .color: return .white
        }
    }
    var next: DisplayTheme {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

enum WheelLayout { case click, row, ring }

/// 셔플 / 아이팟 터치 / 나노 6세대 이후는 제외
enum PodModel: String, CaseIterable, Identifiable {
    case classic = "Classic (6G)", video = "Video (5G)", photo = "Photo (4G)", gen4 = "iPod 4G"
    case mini = "mini", gen3 = "iPod 3G", gen1 = "iPod 1G/2G"
    case nano12 = "nano 1G/2G", nano3 = "nano 3G", nano45 = "nano 4G/5G"

    var id: String { rawValue }

    struct Spec {
        let width: CGFloat
        let lcd: CGFloat
        let wheel: CGFloat
        let layout: WheelLayout
        let color: Bool
        let housings: [Housing]
    }

    var spec: Spec {
        switch self {
        case .classic: return Spec(width: 310, lcd: 200, wheel: 230, layout: .click, color: false, housings: [.white, .black, .silver])
        case .video: return Spec(width: 310, lcd: 215, wheel: 220, layout: .click, color: true, housings: [.white, .black])
        case .photo: return Spec(width: 310, lcd: 195, wheel: 230, layout: .click, color: true, housings: [.white])
        case .gen4: return Spec(width: 310, lcd: 175, wheel: 230, layout: .click, color: false, housings: [.white])
        case .mini: return Spec(width: 250, lcd: 140, wheel: 190, layout: .click, color: false, housings: [.silver, .blue, .pink, .green, .gold])
        case .gen3: return Spec(width: 310, lcd: 175, wheel: 220, layout: .row, color: false, housings: [.white])
        case .gen1: return Spec(width: 300, lcd: 165, wheel: 230, layout: .ring, color: false, housings: [.white])
        case .nano12: return Spec(width: 190, lcd: 150, wheel: 165, layout: .click, color: true, housings: [.white, .black, .blue, .pink, .green])
        case .nano3: return Spec(width: 230, lcd: 130, wheel: 175, layout: .click, color: true, housings: [.silver, .black, .blue, .green, .red])
        case .nano45: return Spec(width: 190, lcd: 170, wheel: 165, layout: .click, color: true, housings: [.silver, .black, .blue, .purple, .green, .orange, .yellow, .pink, .red])
        }
    }
}
