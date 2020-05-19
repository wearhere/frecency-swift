import Foundation

public class Frecency<SearchResult> {
    public enum ResultIdentifier {
        case keyPath(_ keyPath: KeyPath<SearchResult, String>)
        case function(_ function: (SearchResult) -> String)
        
        func id(_ searchResult: SearchResult) -> String {
            switch self {
            case .keyPath(let keyPath): return searchResult[keyPath: keyPath]
            case .function(let function): return function(searchResult)
            }
        }
    }
    
    public struct StorageLimits {
        // Max number of timestamps to save for recent selections of a result.
        var timestamps = 10
        
        // Max number of IDs that should be stored in frecency to limit the object size.
        var recentSelections = 100
    }
    
    // This module expects `exactQuery > subQuery > recentSelection`.
    public struct MatchWeights {
        var exactQuery = 1.0
        var subQuery = 0.7
        var recentSelection = 0.5
    }
    
    private let key: String
    private var defaultsKey: String {
        "com.frecency.defaults.\(key)"
    }
    
    private let storageLimits: StorageLimits
    
    // Internal for the benefit of `Frecency+Scoring` and the tests.
    internal let weights: MatchWeights
    internal let resultIdentifier: ResultIdentifier
    internal lazy var frecency: FrecencyData = loadFrecencyData()
    
    init(
        key: String,
        resultIdentifier: ResultIdentifier,
        storageLimits: StorageLimits = StorageLimits(),
        weights: MatchWeights = MatchWeights()) {
        self.key = key;
        self.resultIdentifier = resultIdentifier
        self.storageLimits = storageLimits
        self.weights = weights
    }
    
    // Reads frecency data from storage and returns the frecency object if
    // the stored frecency data is valid.
    private func loadFrecencyData() -> FrecencyData {
        guard let frecencyData = UserDefaults.standard.data(forKey: defaultsKey),
            let frecency = try? JSONDecoder().decode(FrecencyData.self, from: frecencyData) else {
                return FrecencyData()
        }
        return frecency
    }
    
    // Saves frecency data back to storage.
    private func storeFrecencyData() throws {
        let frecencyData = try JSONEncoder().encode(frecency)
        UserDefaults.standard.set(frecencyData, forKey: defaultsKey)
    }

    // Updates frecency data after user selects a result.
    public func select(_ id: String, for query: String, time: TimeInterval? = nil) throws {
        let time = time ?? Date().timeIntervalSince1970
        frecency.select(id, for: query, time: time, limits: storageLimits)
        try storeFrecencyData()
    }
    
    // Sorts a list of search results based on the saved frecency data.
    // TODO(jeff): Make an asynchronous version of this / make this class
    // thread-safe.
    public func sort(_ results: [SearchResult], for query: String? = nil) -> [SearchResult] {
        let scores = self.scores(for: results, query: query)
        
        // Sort recent selections by frecency. Otherwise, preserve the existing
        // sort order (e.g. that set by the search algorithm).
        let recentSelections = scores.filter { $0.1 > 0 }
        let otherSelections = scores.filter { $0.1 == 0 }
        
        return (
            // Highest score first.
            recentSelections.sorted(by: { $0.1 > $1.1 }) +
            otherSelections)
            .map { $0.0 }
    }
}
