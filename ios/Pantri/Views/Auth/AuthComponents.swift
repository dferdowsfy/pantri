import SwiftUI

// MARK: - Styled Text Field

struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.pantriSecondaryText)
                .frame(width: 20)
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
        }
        .padding(14)
        .background(Color.pantriSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.pantriCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Styled Secure Field

struct AuthSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var showText = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.pantriSecondaryText)
                .frame(width: 20)

            Group {
                if showText {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            Button {
                showText.toggle()
            } label: {
                Image(systemName: showText ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(Color.pantriTertiaryText)
            }
        }
        .padding(14)
        .background(Color.pantriSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.pantriCardBorder, lineWidth: 1)
        )
    }
}
