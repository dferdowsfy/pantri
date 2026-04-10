import SwiftUI
import SwiftData

/// Simple inventory list shown in the sheet when "View all" is tapped
struct InventoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TrackedItem.name) private var items: [TrackedItem]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pantriBackground.ignoresSafeArea()

                if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "basket")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.pantriGreen.opacity(0.35))
                        Text("No items tracked yet")
                            .font(.headline)
                            .foregroundStyle(Color.pantriText)
                    }
                } else {
                    List {
                        ForEach(items.filter { $0.isActive }) { item in
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.pantriGreenLight)
                                        .frame(width: 44, height: 44)
                                    Text(item.category.emoji)
                                        .font(.title3)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.headline)
                                        .foregroundStyle(Color.pantriText)
                                    Text(item.category.displayName)
                                        .font(.caption)
                                        .foregroundStyle(Color.pantriSecondaryText)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("All Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.pantriGreen)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
