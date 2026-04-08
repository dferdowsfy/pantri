import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showReceiptCapture = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)

                AddItemView()
                    .tag(1)

                ChatView()
                    .tag(2)
            }

            // Custom bottom nav matching the mockup design
            HStack {
                // Home tab
                Button {
                    selectedTab = 0
                } label: {
                    Image(systemName: "house.fill")
                        .font(.title2)
                        .foregroundStyle(selectedTab == 0 ? .blue : .gray)
                }
                .frame(maxWidth: .infinity)

                // Add tab (center circle)
                Button {
                    selectedTab = 1
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 48, height: 48)
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundStyle(.gray)
                    }
                }
                .frame(maxWidth: .infinity)

                // Chat tab
                Button {
                    selectedTab = 2
                } label: {
                    Image(systemName: "message.fill")
                        .font(.title2)
                        .foregroundStyle(selectedTab == 2 ? .blue : .gray)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(.white)
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundStyle(Color(.systemGray5)),
                alignment: .top
            )

            // Floating camera button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showReceiptCapture = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.blue)
                                .frame(width: 56, height: 56)
                                .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 80) // Above the tab bar
                }
            }
        }
        .sheet(isPresented: $showReceiptCapture) {
            ReceiptCaptureView()
        }
    }
}
