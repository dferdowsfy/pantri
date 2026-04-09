import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var viewModel = HomeViewModel()
    @Binding var showInventory: Bool

    var body: some View {
        ZStack {
            // ── Nature background ──────────────────────────────────
            Color.pantriOrange.ignoresSafeArea()
            backgroundShapes

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                        .padding(.top, 12)

                    if viewModel.isLoading {
                        ProgressView()
                            .tint(Color.pantriGreen)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let data = viewModel.homeData {
                        if data.totalTrackedItems == 0 {
                            emptyInventoryState
                        } else {
                            if !data.needSoon.isEmpty {
                                needSoonSection(items: data.needSoon)
                            }
                            if !data.thisWeek.isEmpty {
                                thisWeekSection(items: data.thisWeek)
                            }
                            if !data.youreGood.isEmpty {
                                YoureGoodBanner(itemCount: data.youreGood.count)
                            }
                        }
                    } else {
                        emptyInventoryState
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .padding()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110) // clear floating nav
            }
            .refreshable {
                viewModel.refresh(context: modelContext)
            }
        }
        .onAppear {
            viewModel.loadFirstLaunchIfNeeded(context: modelContext, appState: appState)
            viewModel.refresh(context: modelContext)
            Task {
                let service = NotificationService()
                let _ = await service.requestPermission()
            }
        }
    }

    // MARK: - Background shapes

    private var backgroundShapes: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(Color.pantriGreen.opacity(0.12))
                    .frame(width: geo.size.width * 0.7)
                    .offset(x: geo.size.width * 0.5, y: -60)

                Circle()
                    .fill(Color.pantriGreen.opacity(0.08))
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: -geo.size.width * 0.25, y: geo.size.height * 0.6)

                Ellipse()
                    .fill(Color.pantriOrangeAccent.opacity(0.07))
                    .frame(width: geo.size.width * 0.6, height: 200)
                    .offset(x: geo.size.width * 0.1, y: geo.size.height * 0.35)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(Color.pantriGreen)
                    Text("Pantri")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.pantriText)
                }
                Spacer()
                Circle()
                    .fill(Color.pantriGreenLight)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color.pantriGreen)
                    )
            }
            .padding(.bottom, 8)

            Text(viewModel.headlineText)
                .font(.title.weight(.bold))
                .foregroundStyle(Color.pantriText)

            Text(viewModel.subtitleText)
                .foregroundStyle(Color.pantriText.opacity(0.6))
        }
    }

    // MARK: - Empty State

    private var emptyInventoryState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)
            ZStack {
                Circle()
                    .fill(Color.pantriGreenLight)
                    .frame(width: 90, height: 90)
                Image(systemName: "basket")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.pantriGreen)
            }
            VStack(spacing: 8) {
                Text("Your pantry is empty")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.pantriText)
                Text("Tap + to add your first items and Pantri will start predicting when you'll need them.")
                    .font(.subheadline)
                    .foregroundStyle(Color.pantriText.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    private func needSoonSection(items: [ItemSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("You might need soon")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.pantriText)
                Spacer()
                Button {
                    showInventory = true
                } label: {
                    Text("View all")
                        .foregroundStyle(Color.pantriOrangeAccent)
                        .font(.subheadline.weight(.medium))
                }
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
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.pantriText)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    ThisWeekRow(item: item)
                    if item.id != items.last?.id {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
            .background(Color.white.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.pantriGreen.opacity(0.08), radius: 8, y: 2)
        }
    }
}
