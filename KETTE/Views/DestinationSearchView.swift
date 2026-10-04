import SwiftUI

struct DestinationSearchView: View {
    @Bindable var model: MapViewModel
    var isFullScreen = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Where to?", text: $model.query)
                    .accessibilityIdentifier(isFullScreen ? "activeDestinationSearch" : "destinationSearch")
                    .focused($focused)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if isFullScreen {
                    Button("Cancel") {
                        focused = false
                        model.cancelSearch()
                    }
                    .accessibilityIdentifier("cancelSearch")
                }
            }
            .padding()

            if isFullScreen {
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
                    .scrollDismissesKeyboard(.interactively)
                }
            }
        }
        .frame(maxHeight: isFullScreen ? .infinity : nil, alignment: .top)
        .background {
            if isFullScreen {
                Color(uiColor: .systemBackground).ignoresSafeArea()
            } else {
                RoundedRectangle(cornerRadius: 20).fill(.regularMaterial)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(isFullScreen ? "destinationSearchScreen" : "destinationSearchBar")
        .onAppear { if isFullScreen { focused = true } }
        .onChange(of: focused) { _, focused in
            if focused { model.isSearching = true }
        }
        .onChange(of: model.isSearching) { _, searching in
            if !searching || !isFullScreen { focused = false }
        }
    }
}
