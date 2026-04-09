import SwiftUI

struct AnimatedGlobeView: View {
    let isListening: Bool
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let sloshX = sin(time * 2) * 5
            let sloshY = cos(time * 1.5) * 3
            
            ZStack {
                // Background Pulse
                if isListening {
                    Circle()
                        .fill(Color.pantriGreen.opacity(0.12))
                        .frame(width: 240, height: 240)
                        .scaleEffect(1.0 + sin(time * 3) * 0.1)
                }

                // Outer Glass Shell
                Circle()
                    .fill(.white.opacity(0.05))
                    .frame(width: 190, height: 190)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )

                // Liquid Core
                ZStack {
                    // Deep liquid
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.pantriGreenDark, Color.pantriGreen],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .offset(x: isListening ? sloshX : 0, y: isListening ? sloshY : 0)

                    // Moving surface highlight (Water feel)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.4), .clear],
                                center: .init(x: 0.3, y: 0.3),
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .scaleEffect(isListening ? 1.05 : 1.0)
                        .offset(x: isListening ? -sloshX : 0, y: isListening ? -sloshY : 0)

                    // Abstract "Floating" bubbles or land
                    Canvas { context, size in
                        let rect = CGRect(origin: .zero, size: size)
                        let center = CGPoint(x: size.width/2, y: size.height/2)
                        
                        for i in 0..<5 {
                            let angle = time * (1.0 + Double(i) * 0.2) + Double(i)
                            let radius = 30.0 + Double(i) * 10
                            let particleX = center.x + cos(angle) * radius
                            let particleY = center.y + sin(angle) * radius
                            
                            context.fill(
                                Path(ellipseIn: CGRect(x: particleX, y: particleY, width: 8, height: 8)),
                                with: .color(.white.opacity(0.15))
                            )
                        }
                    }
                }
                .mask(Circle())
                .frame(width: 180, height: 180)
                .shadow(color: Color.pantriGreenDark.opacity(0.4), radius: 25, y: 15)

                // Leading Highlight
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .frame(width: 170, height: 170)
                    .blur(radius: 2)
                    .opacity(0.6)
            }
        }
    }
}
