import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showAddItem = false
    @State private var showInventory = false
    @StateObject private var keyboard = KeyboardObserver()

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Content (no horizontal paging) ─────────────────────────
            Group {
                switch selectedTab {
                case 0:  HomeView(showInventory: $showInventory)
                case 2:  ChatView()
                default: Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Floating tab bar ───────────────────────────────────────
            if !keyboard.isVisible {
                floatingNav
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: keyboard.isVisible)
        .sheet(isPresented: $showAddItem) {
            AddItemView()
        }
        .sheet(isPresented: $showInventory) {
            InventoryListView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pantriSwitchToTab)) { notification in
            if let tab = notification.userInfo?["tab"] as? Int {
                withAnimation(.spring(duration: 0.25)) {
                    selectedTab = tab
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pantriOpenShoppingList)) { _ in
            withAnimation(.spring(duration: 0.25)) {
                selectedTab = 0
            }
        }
        .background(Color.pantriBackground.ignoresSafeArea())
    }

    // MARK: - Floating Nav

    private var floatingNav: some View {
        HStack(spacing: 0) {
            navItem(icon: "house.fill", label: "Home", tag: 0)
            scanButton
            navItem(icon: "bubble.left.fill", label: "Chat", tag: 2)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.10), radius: 20, y: 8)
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
        )
        .padding(.horizontal, 36)
        .padding(.bottom, 20)
    }

    private func navItem(icon: String, label: String, tag: Int) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(selectedTab == tag ? Color.pantriGreen : Color.pantriSecondaryText)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(selectedTab == tag ? Color.pantriGreen : Color.pantriTertiaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(duration: 0.25)) {
                selectedTab = tag
            }
        }
    }

    private var scanButton: some View {
        VStack(spacing: 3) {
            Circle()
                .fill(Color.pantriGreen)
                .frame(width: 48, height: 48)
                .shadow(color: Color.pantriGreen.opacity(0.25), radius: 8, y: 2)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                )

            Text("Scan")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.pantriSecondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
        .onTapGesture {
            showAddItem = true
        }
    }
}
