import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let data = viewModel.homeData {
                        // Need Soon section
                        if !data.needSoon.isEmpty {
                            needSoonSection(items: data.needSoon)
                        }

                        // This Week section
                        if !data.thisWeek.isEmpty {
                            thisWeekSection(items: data.thisWeek)
                        }

                        // You're Good section
                        if !data.youreGood.isEmpty {
                            YoureGoodBanner(itemCount: data.youreGood.count)
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .padding()
                    }
                }
                .padding()
            }
            .background(Color(.systemGray6))
            .refreshable {
                viewModel.refresh(context: modelContext)
            }
        }
        .onAppear {
            viewModel.loadFirstLaunchIfNeeded(context: modelContext, appState: appState)
            viewModel.refresh(context: modelContext)

            // Request notification permission on first appearance
            Task {
                let service = NotificationService()
                let _ = await service.requestPermission()
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundStyle(.blue)
                Text("Pantri")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(.gray)
                    )
            }
            .padding(.bottom, 8)

            Text(viewModel.headlineText)
                .font(.title)
                .fontWeight(.bold)

            Text(viewModel.subtitleText)
                .foregroundStyle(.secondary)
        }
    }

    private func needSoonSection(items: [ItemSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("You might need soon")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Text("View inventory")
                    .foregroundStyle(.blue)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            ForEach(items) { item in
                NeedSoonCard(
                    item: item,
                    onBought: { viewModel.handleBought(itemId: item.id, context: modelContext) },
                    onNotYet: { viewModel.handleNotYet(itemId: item.id, context: modelContext) }
                )
            }
        }
    }

    private func thisWeekSection(items: [ItemSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This week")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    ThisWeekRow(item: item)
                    if item.id != items.last?.id {
                        Divider()
                    }
                }
            }
            .padding()
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
    }
}
