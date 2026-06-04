import SwiftUI

/// Rotating border drawn while the model is generating a reply.
struct StreamingInputBorder: View {
    var cornerRadius: CGFloat = 14
    var lineWidth: CGFloat = 2

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let degrees = rotationDegrees(at: timeline.date)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    AngularGradient(
                        colors: gradientColors,
                        center: .center,
                        startAngle: .degrees(degrees),
                        endAngle: .degrees(degrees + 360)
                    ),
                    lineWidth: lineWidth
                )
        }
        .allowsHitTesting(false)
    }

    private var gradientColors: [Color] {
        [
            Color.accentColor.opacity(0.2),
            Color.accentColor.opacity(0.85),
            Color.accentColor,
            Color.white.opacity(0.55),
            Color.accentColor.opacity(0.5),
            Color.accentColor.opacity(0.2),
        ]
    }

    private func rotationDegrees(at date: Date) -> Double {
        let cycle = 2.0
        let t = date.timeIntervalSinceReferenceDate.remainder(dividingBy: cycle) / cycle
        return t * 360
    }
}
