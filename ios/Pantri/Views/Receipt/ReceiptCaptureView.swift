import SwiftUI
import SwiftData
import PhotosUI

struct ReceiptCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ReceiptViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if viewModel.isProcessing {
                    processingView
                } else if viewModel.showResults, let result = viewModel.matchResult {
                    ReceiptResultsView(
                        result: result,
                        onConfirm: {
                            viewModel.confirmMatches(context: modelContext)
                            dismiss()
                        },
                        onCancel: { dismiss() }
                    )
                } else {
                    captureView
                }
            }
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var captureView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Scan a grocery receipt")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Take a photo or select from your library to automatically detect purchased items.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            PhotosPicker(
                selection: $viewModel.selectedPhotoItem,
                matching: .images
            ) {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Spacer()
        }
        .onChange(of: viewModel.selectedPhotoItem) { _, _ in
            Task {
                await viewModel.processSelectedPhoto(context: modelContext)
            }
        }
    }

    private var processingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("Processing receipt...")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Extracting items from your receipt")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }
}
