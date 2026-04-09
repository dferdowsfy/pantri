import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showAddItem = false
    @State private var showInventory = false
    @StateObject private var keyboard = KeyboardObserver()

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Page content ───────────────────────────────────────────
            TabView(selection: $selectedTab) {
                HomeView(showInventory: $showInventory)
                    .tag(0)
                // placeholder — navigation driven by floating bar
                Color.clear.tag(1)
                ChatView()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)

            // ── Floating pill nav (hidden when keyboard is up) ─────────
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
        .background(Color.pantriOrange.ignoresSafeArea())
    }

    // MARK: - Floating Nav

    private var floatingNav: some View {
        HStack(spacing: 0) {
            navItem(icon: "house.fill",   label: "Home",  tag: 0)
            addButton
            navItem(icon: "bubble.left.fill", label: "Chat", tag: 2)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(Color.pantriGreenDark)
                .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
        )
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }

    private func navItem(icon: String, label: String, tag: Int) -> some View {
        Image(systemName: icon)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(selectedTab == tag ? .white : .white.opacity(0.4))
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(duration: 0.3, bounce: 0.25)) {
                    selectedTab = tag
                }
            }
    }

    private var addButton: some View {
        Image(systemName: "plus")
            .font(.system(size: 26, weight: .bold)) // slightly larger than others
            .foregroundStyle(.white.opacity(0.6)) // Base state, maybe .white when pressed
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .onTapGesture {
                showAddItem = true
            }
    }
}
