import SwiftUI

struct DestinationSearchView: View {
    @Bindable var model: MapViewModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Where to?", text: $model.query)
                    .accessibilityIdentifier("destinationSearch")
                    .focused($focused)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if model.isSearching {
                    Button("Cancel") {
                        focused = false
                        model.cancelSearch()
                    }
                    .accessibilityIdentifier("cancelSearch")
                }
            }
            .padding()

            if model.isSearching {
                if model.isResolving {
                    ProgressView("Loading destination …")
                        .padding()
                } else if let error = model.searchError {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                    Button("Try again") {
                        let query = model.query
                        model.query = query
                    }
                    .padding(.bottom)
                }
                if !model.suggestions.isEmpty {
                    Divider()
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(model.suggestions) { suggestion in
                                Button {
                                    Task { await model.select(suggestion) }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(suggestion.title)
                                            .foregroundStyle(.primary)
                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(model.isResolving)
                                Divider()
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                    .scrollDismissesKeyboard(.interactively)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .onChange(of: focused) { _, focused in
            if focused { model.isSearching = true }
        }
        .onChange(of: model.isSearching) { _, searching in
            if !searching { focused = false }
        }
    }
}
