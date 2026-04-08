import SwiftUI

struct YoureGoodBanner: View {
    let itemCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 24, height: 24)
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

                Text("You're good")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.systemGreen).opacity(0.9))
            }

            Text("Everything else in your pantry is well-stocked. \(itemCount) item\(itemCount == 1 ? "" : "s") looking fine.")
                .font(.subheadline)
                .foregroundStyle(Color(.systemGreen).opacity(0.8))

            HStack(spacing: 4) {
                Text("Check full report")
                    .fontWeight(.semibold)
                    .font(.subheadline)
                Image(systemName: "arrow.right")
                    .font(.caption)
            }
            .foregroundStyle(Color(.systemGreen).opacity(0.9))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }
}
