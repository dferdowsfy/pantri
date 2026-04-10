import SwiftUI

struct SplashView: View {
    @State private var leafScale: CGFloat = 0.3
    @State private var leafOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 12
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.pantriOrange.ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    // Soft ring behind leaf
                    Circle()
                        .fill(Color.pantriGreenLight)
                        .frame(width: 110, height: 110)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Leaf icon
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(Color.pantriGreen)
                        .scaleEffect(leafScale)
                        .opacity(leafOpacity)
                }

                Text("Pantri")
                    .font(.system(size: 32, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.pantriText)
                    .opacity(textOpacity)
                    .offset(y: textOffset)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.4)) {
                leafScale = 1.0
                leafOpacity = 1.0
                ringScale = 1.0
                ringOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.25)) {
                textOpacity = 1.0
                textOffset = 0
            }
        }
    }
}
