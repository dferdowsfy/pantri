import SwiftUI

/// A clean, native-feeling row for items in the "What to buy" list.
/// Swipe actions and context menus are applied by the parent List.
struct NeedSoonCard: View {
    let item: ItemSummary
    var isBought: Bool = false

    private var urgencyColor: Color {
        switch item.urgency {
        case .urgent: return .urgencyRed
        case .soon:   return .urgencyYellow
        case .stable: return .urgencyGreen
        }
    }

    private var statusTextColor: Color {
        switch item.urgency {
        case .urgent: return .urgencyRed
        case .soon:   return .urgencyYellow
        case .stable: return Color.pantriSecondaryText
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Thin urgency indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(urgencyColor)
                .frame(width: 3, height: 36)

            ItemImageView(itemName: item.name, category: item.category, size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .foregroundStyle(isBought ? Color.pantriTertiaryText : Color.pantriText)
                    .strikethrough(isBought, color: Color.pantriTertiaryText)
                Text(isBought ? "Bought" : item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(isBought ? Color.pantriGreen : statusTextColor)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.pantriTertiaryText)
        }
        .padding(.vertical, 4)
    }
}
