import SwiftUI

struct ItemActionButton: View {
    let title: String
    let style: Style
    let action: () -> Void

    enum Style {
        case primary
        case secondary
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .foregroundStyle(foregroundColor)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return Color.pantriGreen
        case .secondary: return Color.pantriText.opacity(0.5)
        }
    }
}

struct StatusBadge: View {
    let status: ItemStatus

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(backgroundColor)
    }

    private var label: String {
        switch status {
        case .good: return "Good"
        case .needSoon: return "Need Soon"
        case .buyNow: return "Buy Now"
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .good: return .green
        case .needSoon: return .orange
        case .buyNow: return .red
        }
    }
}
