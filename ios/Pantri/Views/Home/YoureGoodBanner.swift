import SwiftUI

struct YoureGoodBanner: View {
    let itemCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.pantriGreen)
                        .frame(width: 26, height: 26)
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                }
                Text("You're well-stocked")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.pantriGreenDark)
            }

            Text("\(itemCount) item\(itemCount == 1 ? "" : "s") in good shape — no action needed.")
                .font(.subheadline)
                .foregroundStyle(Color.pantriGreen)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pantriGreenLight)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.pantriGreen.opacity(0.25), lineWidth: 1)
        )
    }
}
