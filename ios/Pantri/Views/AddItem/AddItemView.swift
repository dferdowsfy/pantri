import SwiftUI
import SwiftData

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddItemViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Item name", text: $viewModel.name)
                        .textInputAutocapitalization(.words)

                    Picker("Category", selection: $viewModel.selectedCategory) {
                        ForEach(ItemCategory.allCases) { category in
                            HStack {
                                Text(category.emoji)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }

                    Toggle("Perishable", isOn: $viewModel.isPerishable)
                }

                Section("Consumption Estimate (Optional)") {
                    TextField("Days between purchases", text: $viewModel.baselineDaysOverride)
                        .keyboardType(.numberPad)

                    Text("Leave blank to use a sensible default based on the category.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save(context: modelContext)
                    }
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                }
            }
            .onChange(of: viewModel.didSave) { _, saved in
                if saved { dismiss() }
            }
        }
    }
}
