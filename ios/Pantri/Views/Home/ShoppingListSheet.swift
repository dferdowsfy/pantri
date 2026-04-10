import SwiftUI
import SwiftData

struct ShoppingListSheet: View {
    let items: [ItemSummary]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var checked: Set<UUID> = []

    private var allChecked: Bool {
        !items.isEmpty && checked.count == items.count
    }

    private var checkedCount: Int { checked.count }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pantriBackground.ignoresSafeArea()

                if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cart")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.pantriGreen.opacity(0.35))
                        Text("Nothing due right now")
                            .font(.headline)
                            .foregroundStyle(Color.pantriText)
                        Text("Check back later — Pantri will let you know.")
                            .font(.subheadline)
                            .foregroundStyle(Color.pantriSecondaryText)
                    }
                } else {
                    VStack(spacing: 0) {
                        List {
                            ForEach(items) { item in
                                shoppingRow(item)
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)

                        // Done Shopping button
                        if checkedCount > 0 {
                            doneShoppingButton
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(duration: 0.3), value: checkedCount)
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.pantriSecondaryText)
                }
            }
        }
    }

    // MARK: - Done Shopping Button

    private var doneShoppingButton: some View {
        Button {
            markCheckedAsBought()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.body.weight(.bold))
                Text(allChecked ? "Done Shopping" : "Mark \(checkedCount) as Bought")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.pantriGreen)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.pantriBackground)
    }

    // MARK: - Row

    private func shoppingRow(_ item: ItemSummary) -> some View {
        Button {
            withAnimation(.spring(duration: 0.25)) {
                if checked.contains(item.id) {
                    checked.remove(item.id)
                } else {
                    checked.insert(item.id)
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
            }
        } label: {
            HStack(spacing: 14) {
                ItemImageView(itemName: item.name, category: item.category, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.subheadline)
                        .foregroundStyle(Color.pantriText)
                        .strikethrough(checked.contains(item.id), color: Color.pantriTertiaryText)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.pantriSecondaryText)
                }

                Spacer()

                Image(systemName: checked.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(checked.contains(item.id) ? Color.pantriGreen : Color.pantriTertiaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(checked.contains(item.id) ? 0.55 : 1.0)
    }

    // MARK: - Actions

    private func markCheckedAsBought() {
        let learningService = LearningService()
        var succeeded = 0

        for itemId in checked {
            let descriptor = FetchDescriptor<TrackedItem>(
                predicate: #Predicate { $0.id == itemId }
            )
            guard let item = try? modelContext.fetch(descriptor).first else { continue }
            do {
                try learningService.recordBought(item: item, context: modelContext)
                succeeded += 1
            } catch {
                // Continue with remaining items
            }
        }

        if succeeded > 0 {
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
            NotificationCenter.default.post(name: .pantriInventoryChanged, object: nil)
        }

        dismiss()
    }
}
