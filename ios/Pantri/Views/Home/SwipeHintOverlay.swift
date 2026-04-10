import SwiftUI

struct SwipeHintOverlay: View {
    @Binding var isVisible: Bool
    @State private var arrowOffset: CGFloat = 0

    var body: some View {
        if isVisible {
            VStack(spacing: 16) {
                Spacer()

                VStack(spacing: 12) {
                    HStack(spacing: 24) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left")
                                .offset(x: -arrowOffset)
                            Text("Snooze")
                        }
                        .foregroundStyle(.white.opacity(0.7))

                        Text("·")
                            .foregroundStyle(.white.opacity(0.3))

                        HStack(spacing: 6) {
                            Text("Bought")
                            Image(systemName: "arrow.right")
                                .offset(x: arrowOffset)
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    .font(.subheadline.weight(.medium))

                    Text("Swipe cards to take action")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color.pantriGreenDark.opacity(0.95))
                )
                .padding(.bottom, 130)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatCount(3, autoreverses: true)) {
                    arrowOffset = 6
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isVisible = false
                    }
                }
            }
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.2)) {
                    isVisible = false
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}
