import SwiftUI

struct ClickWheel: View {
    let spec: PodModel.Spec
    let housing: Housing
    let step: (Int) -> Void
    let center: () -> Void
    let menu: () -> Void
    let next: () -> Void
    let prev: () -> Void
    let playPause: () -> Void

    @State private var last: Double?
    @State private var acc: Double = 0
    private let degPerStep = 28.0

    var body: some View {
        let s = spec.wheel
        VStack(spacing: 12) {
            if spec.layout == .row {
                HStack(spacing: 4) {
                    key("MENU", menu, shape: 2)
                    key("⏮", prev, shape: 2)
                    key("⏯", playPause, shape: 2)
                    key("⏭", next, shape: 2)
                }
            }
            ZStack {
                face(spec.layout == .ring ? s - 68 : s)
                switch spec.layout {
                case .click:
                    let r = s / 2 - 24
                    key("MENU", menu).offset(y: -r)
                    key("⏭", next).offset(x: r)
                    key("⏮", prev).offset(x: -r)
                    key("⏯", playPause).offset(y: r)
                case .ring:
                    let r = s / 2 - 17
                    key("MENU", menu, shape: 1).offset(y: -r)
                    key("⏭", next, shape: 1).offset(x: r)
                    key("⏮", prev, shape: 1).offset(x: -r)
                    key("⏯", playPause, shape: 1).offset(y: r)
                case .row:
                    EmptyView()
                }
                Button(action: center) {
                    Circle().fill(housing.body)
                        .frame(width: s * 0.36, height: s * 0.36)
                        .overlay(Circle().stroke(Color.black.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            .frame(width: s, height: s)
        }
    }

    private func face(_ f: CGFloat) -> some View {
        Circle().fill(housing.wheel)
            .frame(width: f, height: f)
            .contentShape(Circle())
            .gesture(drag(f))
    }

    /// 원형 제스처: 각도 변화를 누적해 일정 각도마다 한 칸씩 이동
    private func drag(_ f: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let p = CGPoint(x: v.location.x - f / 2, y: v.location.y - f / 2)
                guard hypot(p.x, p.y) > f * 0.18 else { return }
                let a = atan2(p.y, p.x) * 180 / .pi
                if let l = last {
                    var d = a - l
                    if d > 180 { d -= 360 }
                    if d < -180 { d += 360 }
                    acc += d
                    while acc >= degPerStep { step(1); acc -= degPerStep }
                    while acc <= -degPerStep { step(-1); acc += degPerStep }
                }
                last = a
            }
            .onEnded { _ in last = nil; acc = 0 }
    }

    private func key(_ t: String, _ a: @escaping () -> Void, shape: Int = 0) -> some View {
        Button(action: a) {
            Text(t)
                .font(.system(size: shape == 1 ? 10 : 13, weight: .bold))
                .foregroundColor(housing.label)
                .frame(width: shape == 1 ? 34 : (shape == 2 ? 52 : 50), height: shape == 1 ? 34 : 36)
                .background {
                    if shape == 1 { Circle().fill(housing.wheel) }
                    else if shape == 2 { Capsule().fill(housing.wheel) }
                }
        }
        .buttonStyle(.plain)
    }
}
