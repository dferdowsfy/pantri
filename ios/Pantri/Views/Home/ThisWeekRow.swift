import SwiftUI

struct ThisWeekRow: View {
    let item: ItemSummary

    var body: some View {
        HStack(spacing: 12) {
            ItemImageView(itemName: item.name, category: item.category, size: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.regular))
                    .foregroundStyle(Color.pantriText)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.pantriSecondaryText)
            }

            Spacer()

            Text(item.subtitle)
                .font(.caption.weight(.regular))
                .foregroundStyle(Color.pantriTertiaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }
}
