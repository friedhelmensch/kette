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
                    .accessibilityIdentifier("activeDestinationSearch")
                    .focused($focused)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                Button("Cancel") {
                    focused = false
                    model.cancelSearch()
                }
                .accessibilityIdentifier("cancelSearch")
            }
            .padding()

            if model.isResolving {
                ProgressView("Loading destination …")
                    .padding()
            } else if let error = model.searchError {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                Button("Try again", action: model.retrySearch)
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
            Spacer(minLength: 0)
            HStack {
                Text("Routing:")
                Link("BRouter", destination: URL(string: "https://brouter.de/")!)
                Text("·")
                Link("© OpenStreetMap contributors", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding()
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("destinationSearchScreen")
        .onAppear { focused = true }
    }
}
