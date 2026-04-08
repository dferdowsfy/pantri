import SwiftUI

struct ReceiptResultsView: View {
    let result: ReceiptMatchResult
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Matched items
            if !result.matched.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Matched Items")
                            .font(.headline)
                    }

                    Text("These items were matched to your tracked inventory.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(result.matched, id: \.item.id) { match in
                        HStack {
                            Text(match.item.category.emoji)
                            Text(match.item.name)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Unmatched items
            if !result.unmatched.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.orange)
                        Text("Unrecognized Items")
                            .font(.headline)
                    }

                    Text("These items weren't matched to anything you're tracking.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(result.unmatched, id: \.normalizedName) { item in
                        HStack {
                            Text(item.normalizedName.capitalized)
                            Spacer()
                            Text("Not tracked")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer()

            // Actions
            if !result.matched.isEmpty {
                Button(action: onConfirm) {
                    Text("Record \(result.matched.count) Purchase\(result.matched.count == 1 ? "" : "s")")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Button("Cancel", action: onCancel)
                .frame(maxWidth: .infinity)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
