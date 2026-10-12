import SwiftUI

/// Dark gradient with two soft glows drifting very slowly. Static when Reduce Motion is on.
struct SessionBackground: View {
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            Theme.Colors.background
            if reduceMotion {
                glows(time: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                    glows(time: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func glows(time: TimeInterval) -> some View {
        let t = time / 18
        let driftA = CGPoint(x: cos(t), y: sin(t * 0.8))
        let driftB = CGPoint(x: sin(t * 0.7), y: cos(t))
        return GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                Circle()
                    .fill(Theme.Colors.lavender.opacity(0.14))
                    .frame(width: width * 1.1, height: width * 1.1)
                    .blur(radius: 80)
                    .offset(x: driftA.x * width * 0.15, y: height * -0.18 + driftA.y * 30)
                Circle()
                    .fill(Theme.Colors.dusk.opacity(0.55))
                    .frame(width: width, height: width)
                    .blur(radius: 90)
                    .offset(x: driftB.x * width * 0.2, y: height * 0.28 + driftB.y * 40)
            }
            .frame(width: width, height: height)
        }
    }
}
