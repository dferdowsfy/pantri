import SwiftUI
import SwiftData

struct ItemDetailView: View {
    let itemId: UUID
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ItemDetailViewModel()

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else if let item = viewModel.item, let prediction = viewModel.prediction {
                VStack(alignment: .leading, spacing: 24) {
                    // Item header
                    itemHeader(item: item, prediction: prediction)

                    // Prediction card
                    predictionCard(prediction: prediction)

                    // Action buttons
                    actionButtons

                    // Purchase history
                    if !viewModel.purchaseHistory.isEmpty {
                        purchaseHistorySection
                    }

                    // Item settings
                    if let profile = item.consumptionProfile {
                        settingsSection(profile: profile)
                    }
                }
                .padding()
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding()
            }
        }
        .background(Color.pantriBackground)
        .navigationTitle(viewModel.item?.name ?? "Item")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if let item = fetchItem() {
                viewModel.load(item: item, context: modelContext)
            }
        }
    }

    // MARK: - Subviews

    private func itemHeader(item: TrackedItem, prediction: ItemPrediction) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.pantriGreenLight)
                    .frame(width: 80, height: 80)
                Text(prediction.emoji)
                    .font(.largeTitle)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(item.category.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                StatusBadge(status: prediction.status)
            }
        }
    }

    private func predictionCard(prediction: ItemPrediction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prediction")
                .font(.headline)

            Text(prediction.explanation)
                .foregroundStyle(.secondary)

            HStack {
                Label("Confidence", systemImage: "chart.bar.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(prediction.confidenceScore * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color.pantriSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            ItemActionButton(title: "Bought", style: .primary) {
                viewModel.handleBought(context: modelContext)
            }
            ItemActionButton(title: "Not yet", style: .secondary) {
                viewModel.handleNotYet(context: modelContext)
            }
            ItemActionButton(title: "Remind later", style: .secondary) {
                viewModel.handleRemindLater(context: modelContext)
            }
        }
    }

    private var purchaseHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Purchase History")
                .font(.headline)

            ForEach(viewModel.purchaseHistory.prefix(10), id: \.id) { event in
                HStack {
                    Image(systemName: "bag.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)

                    Text(event.purchasedAt, style: .date)
                        .font(.subheadline)

                    Spacer()

                    Text(event.source.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.pantriSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func settingsSection(profile: ConsumptionProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Item Settings")
                .font(.headline)

            LabeledContent("Baseline interval", value: "\(Int(profile.baselineDays)) days")
            LabeledContent("Current estimate", value: "\(Int(profile.currentEstimatedDays)) days")
            LabeledContent("Reminder lead time", value: "\(profile.reminderLeadDays) days")
            LabeledContent("Perishable", value: profile.isPerishable ? "Yes" : "No")
        }
        .padding()
        .background(Color.pantriSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func fetchItem() -> TrackedItem? {
        let descriptor = FetchDescriptor<TrackedItem>(
            predicate: #Predicate { $0.id == itemId }
        )
        return try? modelContext.fetch(descriptor).first
    }
}
