import SwiftUI

struct ThisWeekRow: View {
    let item: ItemSummary

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 32, height: 32)
                Text(item.emoji)
                    .font(.caption)
            }

            Text(item.name)
                .fontWeight(.medium)

            Spacer()

            Text(item.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}
