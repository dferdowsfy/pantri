import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var viewModel = HomeViewModel()
    @Binding var showInventory: Bool
    @State private var showShoppingList = false
    @State private var selectedItemId: UUID?
    @State private var boughtIds: Set<UUID> = []
    @State private var removingIds: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                // ── Header ─────────────────────────────────────────
                Section {
                    headerSection
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 4, trailing: 20))

                if viewModel.isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(Color.pantriGreen)
                            Spacer()
                        }
                        .frame(minHeight: 200)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                } else if let data = viewModel.homeData {
                    if data.totalTrackedItems == 0 {
                        Section { emptyInventoryState }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        // ── Shopping List Summary Card ──────────────
                        if !viewModel.whatToBuyItems.isEmpty {
                            Section {
                                shoppingListCard(count: viewModel.whatToBuyItems.count)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                        }

                        // ── What to Buy ────────────────────────────
                        if !viewModel.whatToBuyItems.isEmpty {
                            Section {
                                ForEach(viewModel.whatToBuyItems) { item in
                                    if !removingIds.contains(item.id) {
                                        NeedSoonCard(item: item, isBought: boughtIds.contains(item.id))
                                            .contentShape(Rectangle())
                                            .onTapGesture { selectedItemId = item.id }
                                            .listRowBackground(
                                                Color.pantriSurface
                                                    .overlay(alignment: .bottom) {
                                                        Rectangle()
                                                            .fill(Color.pantriCardBorder)
                                                            .frame(height: 0.5)
                                                    }
                                            )
                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                Button {
                                                    animateBought(itemId: item.id)
                                                } label: {
                                                    Label("Bought", systemImage: "checkmark.circle.fill")
                                                }
                                                .tint(Color.pantriGreen)

                                                Button {
                                                    animateSnooze(itemId: item.id)
                                                } label: {
                                                    Label("Snooze", systemImage: "clock")
                                                }
                                                .tint(Color(.systemGray))

                                                Button {
                                                    showShoppingList = true
                                                } label: {
                                                    Label("List", systemImage: "cart.badge.plus")
                                                }
                                                .tint(Color(.systemIndigo))
                                            }
                                            .contextMenu {
                                                Button {
                                                    animateBought(itemId: item.id)
                                                } label: {
                                                    Label("Mark as Bought", systemImage: "checkmark.circle")
                                                }
                                                Button {
                                                    animateSnooze(itemId: item.id)
                                                } label: {
                                                    Label("Snooze 3 Days", systemImage: "clock")
                                                }
                                                Button {
                                                    showShoppingList = true
                                                } label: {
                                                    Label("Add to Shopping List", systemImage: "cart.badge.plus")
                                                }
                                                Divider()
                                                Button {
                                                    selectedItemId = item.id
                                                } label: {
                                                    Label("View Details", systemImage: "info.circle")
                                                }
                                            }
                                            .transition(.asymmetric(
                                                insertion: .opacity,
                                                removal: .move(edge: .trailing).combined(with: .opacity)
                                            ))
                                    }
                                }
                            } header: {
                                whatToBuyHeader
                            }
                        }

                        // ── You're Good Banner ─────────────────────
                        if !data.youreGood.isEmpty {
                            Section {
                                YoureGoodBanner(itemCount: data.youreGood.count)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 0, trailing: 20))
                        }
                    }
                } else {
                    Section { emptyInventoryState }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(Color.urgencyRed)
                            .font(.caption)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.pantriBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 90)
            }
            .refreshable {
                viewModel.refresh(context: modelContext)
            }
            .navigationDestination(item: $selectedItemId) { itemId in
                ItemDetailView(itemId: itemId)
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
        .onChange(of: showInventory) { _, _ in
            viewModel.refresh(context: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .pantriInventoryChanged)) { _ in
            viewModel.refresh(context: modelContext)
        }
        .sheet(isPresented: $showShoppingList) {
            ShoppingListSheet(items: viewModel.whatToBuyItems)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.headlineText)
                .font(.title.weight(.semibold))
                .foregroundStyle(Color.pantriText)

            Text(viewModel.subtitleText)
                .font(.body)
                .foregroundStyle(Color.pantriSecondaryText)

            Text("Pantri learns from receipts and habits.")
                .font(.caption)
                .foregroundStyle(Color.pantriTertiaryText)
                .padding(.top, 2)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Shopping List Card

    private func shoppingListCard(count: Int) -> some View {
        Button { showShoppingList = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.pantriGreen)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.pantriGreenLight))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Shopping List")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.pantriText)
                    Text("\(count) item\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(Color.pantriSecondaryText)
                }

                Spacer()

                Text("Review")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.pantriGreen)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.pantriSurface)
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.pantriCardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - What to Buy Header

    private var whatToBuyHeader: some View {
        HStack {
            Text("What to buy")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.pantriSecondaryText)
                .textCase(nil)
            Spacer()
            Button { showInventory = true } label: {
                Text("View all")
                    .font(.subheadline)
                    .foregroundStyle(Color.pantriTertiaryText)
            }
        }
    }

    // MARK: - Empty State

    private var emptyInventoryState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)
            ZStack {
                Circle()
                    .fill(Color.pantriGreenLight)
                    .frame(width: 80, height: 80)
                Image(systemName: "basket")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.pantriGreen)
            }
            VStack(spacing: 6) {
                Text("Your pantry is empty")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.pantriText)
                Text("Tap + to scan a receipt or add items.")
                    .font(.subheadline)
                    .foregroundStyle(Color.pantriSecondaryText)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Swipe Action Animations

    private func animateBought(itemId: UUID) {
        // 1. Strikethrough + checkmark state
        withAnimation(.easeInOut(duration: 0.3)) {
            boughtIds.insert(itemId)
        }
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)

        // 2. After a beat, fly away and record
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeIn(duration: 0.35)) {
                removingIds.insert(itemId)
            }
            // 3. Record in data layer after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                viewModel.handleBought(itemId: itemId, context: modelContext)
                boughtIds.remove(itemId)
                removingIds.remove(itemId)
            }
        }
    }

    private func animateSnooze(itemId: UUID) {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        withAnimation(.easeIn(duration: 0.35)) {
            removingIds.insert(itemId)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            viewModel.handleSnooze(itemId: itemId, context: modelContext)
            removingIds.remove(itemId)
        }
    }
}
