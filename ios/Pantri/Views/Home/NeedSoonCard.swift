import SwiftUI

struct NeedSoonCard: View {
    let item: ItemSummary
    let onBought: () -> Void
    let onNotYet: () -> Void

    @State private var boughtPressed = false
    @State private var notYetPressed = false
    @State private var showConfetti = false

    var body: some View {
        HStack(spacing: 14) {
            // Emoji icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.pantriGreenLight)
                    .frame(width: 60, height: 60)
                Text(item.emoji)
                    .font(.title2)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.pantriText)

                Text(item.explanation)
                    .font(.subheadline)
                    .foregroundStyle(Color.pantriText.opacity(0.6))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // Bought button
                    Button {
                        withAnimation(.spring(duration: 0.3, bounce: 0.5)) {
                            boughtPressed = true
                        }
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            onBought()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: boughtPressed ? "checkmark" : "cart.badge.plus")
                                .font(.caption.weight(.bold))
                            Text("Bought")
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.pantriGreen)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .scaleEffect(boughtPressed ? 0.92 : 1.0)
                    }

                    // Not yet button
                    Button {
                        withAnimation(.spring(duration: 0.3, bounce: 0.4)) {
                            notYetPressed = true
                        }
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            notYetPressed = false
                            onNotYet()
                        }
                    } label: {
                        Text("Not yet")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.pantriOrange)
                            .foregroundStyle(Color.pantriText.opacity(0.75))
                            .clipShape(Capsule())
                            .scaleEffect(notYetPressed ? 0.92 : 1.0)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.white.opacity(0.8))
                .shadow(color: Color.pantriGreen.opacity(0.10), radius: 10, y: 3)
        )
    }
}
