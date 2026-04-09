import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddItemViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pantriOrange.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Item name
                        fieldCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Item Name", systemImage: "tag.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.pantriGreen)
                                TextField("e.g. Milk, Coffee, Eggs…", text: $viewModel.name)
                                    .font(.body)
                                    .foregroundStyle(Color.pantriText)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                            }
                        }

                        // Category picker
                        fieldCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Category", systemImage: "square.grid.2x2.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.pantriGreen)
                                Picker("", selection: $viewModel.selectedCategory) {
                                    ForEach(ItemCategory.allCases) { cat in
                                        Text("\(cat.emoji) \(cat.displayName)").tag(cat)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 120)
                            }
                        }

                        // Perishable toggle
                        fieldCard {
                            HStack {
                                Label("Perishable", systemImage: "clock.fill")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.pantriText)
                                Spacer()
                                Toggle("", isOn: $viewModel.isPerishable)
                                    .tint(Color.pantriGreen)
                            }
                        }

                        // Days override
                        fieldCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Days Between Purchases (optional)", systemImage: "calendar")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.pantriGreen)
                                TextField("Leave blank for smart default", text: $viewModel.baselineDaysOverride)
                                    .keyboardType(.numberPad)
                                    .font(.body)
                                    .foregroundStyle(Color.pantriText)
                                Text("We'll pick a sensible default based on the category.")
                                    .font(.caption)
                                    .foregroundStyle(Color.pantriText.opacity(0.4))
                            }
                        }

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }

                        // Save button
                        Button {
                            viewModel.save(context: modelContext)
                        } label: {
                            HStack {
                                if viewModel.isSaving {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.85)
                                } else {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.bold))
                                    Text("Save Item")
                                        .font(.body.weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                viewModel.isValid
                                    ? Color.pantriGreen
                                    : Color.pantriGreenLight
                            )
                            .foregroundStyle(
                                viewModel.isValid ? .white : Color.pantriGreen.opacity(0.4)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: viewModel.isValid ? Color.pantriGreen.opacity(0.30) : .clear, radius: 8, y: 4)
                        }
                        .disabled(!viewModel.isValid || viewModel.isSaving)
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.pantriText.opacity(0.5))
                }
            }
            .onChange(of: viewModel.didSave) { _, saved in
                if saved {
                    let impact = UINotificationFeedbackGenerator()
                    impact.notificationOccurred(.success)
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private func fieldCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.82))
                    .shadow(color: Color.pantriGreen.opacity(0.07), radius: 8, y: 2)
            )
            .padding(.horizontal)
    }
}
