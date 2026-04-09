import SwiftUI

struct ThisWeekRow: View {
    let item: ItemSummary

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.pantriGreenLight)
                    .frame(width: 38, height: 38)
                Text(item.emoji)
                    .font(.body)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.pantriText)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.pantriText.opacity(0.5))
            }

            Spacer()

            Text(item.subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.pantriGreen)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.pantriGreenLight)
                .clipShape(Capsule())
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }
}
