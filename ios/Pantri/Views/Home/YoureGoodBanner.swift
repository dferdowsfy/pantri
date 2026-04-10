import SwiftUI

struct YoureGoodBanner: View {
    let itemCount: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.pantriGreen.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.pantriGreen)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("You're well-stocked")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.pantriText)
                Text("\(itemCount) item\(itemCount == 1 ? "" : "s") in good shape.")
                    .font(.caption)
                    .foregroundStyle(Color.pantriSecondaryText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.pantriSurface)
                .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
        )
    }
}
