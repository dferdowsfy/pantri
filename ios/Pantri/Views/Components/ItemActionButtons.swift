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
                .background(backgroundColor)
                .foregroundStyle(foregroundColor)
                .clipShape(Capsule())
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return .blue
        case .secondary: return Color(.systemGray6)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return .primary
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
            .background(backgroundColor.opacity(0.15))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
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
