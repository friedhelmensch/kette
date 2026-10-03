import MapKit

@MainActor
final class DestinationSearchService: NSObject, DestinationSearching, @preconcurrency MKLocalSearchCompleterDelegate {
    private var completer: MKLocalSearchCompleter?
    private var completions: [String: MKLocalSearchCompletion] = [:]
    private var activeSearch: MKLocalSearch?
    private(set) var suggestions: [SearchSuggestion] = []
    private(set) var errorMessage: String?
    var onChange: (() -> Void)?

    func updateQuery(_ query: String) {
        completer?.delegate = nil
        completer = nil
        completions = [:]
        suggestions = []
        errorMessage = nil
        guard !query.isEmpty else { onChange?(); return }
        let completer = MKLocalSearchCompleter()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        self.completer = completer
        completer.queryFragment = query
        onChange?()
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard completer === self.completer else { return }
        completions = [:]
        suggestions = completer.results.enumerated().map { index, completion in
            let id = String(index)
            completions[id] = completion
            return SearchSuggestion(id: id, title: completion.title, subtitle: completion.subtitle)
        }
        errorMessage = nil
        onChange?()
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        guard completer === self.completer else { return }
        suggestions = []
        errorMessage = "Search failed. Please try again."
        onChange?()
    }

    func resolve(_ suggestion: SearchSuggestion) async throws -> Destination {
        guard let completion = completions[suggestion.id] else { throw SearchError.noResult }
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        activeSearch = search
        defer { if activeSearch === search { activeSearch = nil } }
        let response = try await search.start()
        try Task.checkCancellation()
        guard let item = response.mapItems.first else { throw SearchError.noResult }
        return Destination(
            name: item.name ?? suggestion.title,
            subtitle: suggestion.subtitle.isEmpty ? nil : suggestion.subtitle,
            latitude: item.location.coordinate.latitude,
            longitude: item.location.coordinate.longitude
        )
    }

    func cancel() {
        activeSearch?.cancel()
        activeSearch = nil
    }

    private enum SearchError: Error { case noResult }
}
