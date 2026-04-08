import SwiftUI

struct NeedSoonCard: View {
    let item: ItemSummary
    let onBought: () -> Void
    let onNotYet: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Item emoji/icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(width: 64, height: 64)
                Text(item.emoji)
                    .font(.title)
            }

            // Item info + actions
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.headline)

                Text(item.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ItemActionButton(title: "Bought", style: .primary, action: onBought)
                    ItemActionButton(title: "Not yet", style: .secondary, action: onNotYet)
                }
            }
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}
