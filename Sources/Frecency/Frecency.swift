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
        public var timestamps: Int
        
        // Max number of IDs that should be stored in frecency to limit the object size.
        public var recentSelections: Int
        
        // Unfortunately, default memberwise initializers are merely internal.
        public init(timestamps: Int = 10, recentSelections: Int = 100) {
            self.timestamps = timestamps
            self.recentSelections = recentSelections
        }
    }
    
    // This module expects `exactQuery > subQuery > recentSelection`.
    public struct MatchWeights {
        public var exactQuery: Double
        public var subQuery: Double
        public var recentSelection: Double
        
        // Unfortunately, default memberwise initializers are merely internal.
        public init(exactQuery: Double = 1.0,
             subQuery: Double = 0.7,
             recentSelection: Double = 0.5) {
            self.exactQuery = exactQuery
            self.subQuery = subQuery
            self.recentSelection = recentSelection
        }
    }
    
    private let key: String
    private var defaultsKey: String {
        "com.frecency.defaults.\(key)"
    }
    
    private let storageLimits: StorageLimits
    
    // Internal for the benefit of `Frecency+Scoring` and the tests.
    internal let weights: MatchWeights
    internal let resultIdentifier: ResultIdentifier
    internal var frecency: FrecencyData!
    
    private lazy var frecencyQueue: DispatchQueue = {
        DispatchQueue(label: "com.frecency.frecencyqueues.\(key)", qos: .userInteractive, attributes: .concurrent)
    }()
    
    public init(
        key: String,
        resultIdentifier: ResultIdentifier,
        storageLimits: StorageLimits = StorageLimits(),
        weights: MatchWeights = MatchWeights()) {
        self.key = key;
        self.resultIdentifier = resultIdentifier
        self.storageLimits = storageLimits
        self.weights = weights
        
        frecencyQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.frecency = self.loadFrecencyData()
        }
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
    
    // TODO(jeff): Figure out how to test the error handler. I don't think that
    // storage ever fails given that our data does not contain any doubles
    // nor floats and we don't manually encode
    // https://github.com/apple/swift/blob/bf1b17d4ed08120d43c7b9d0c57a169e1386beca/test/stdlib/TestJSONEncoder.swift#L467
    public func select(_ id: String, for query: String? = nil, time: TimeInterval? = nil, errorHandler: ((Error) -> Void)? = nil) {
        let time = time ?? Date().timeIntervalSince1970
        
        frecencyQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.frecency.select(id, for: query, time: time, limits: self.storageLimits)
            do {
                try self.storeFrecencyData()
            } catch {
                guard let errorHandler = errorHandler else { return }
                errorHandler(error)
            }
        }
    }
    
    // Resets stored frecency data.
    public func reset() {
        frecencyQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            UserDefaults.standard.removeObject(forKey: self.defaultsKey)
            self.frecency = FrecencyData()
        }
    }
    
    // Blocks until the object has finished processing any updates to frecency
    // data including writing the data to disk.
    //
    // Useful in the tests, and in your app if you plan to dismiss your UI
    // immediately after updating the selection.
    //
    // If you don't need this to be synchronous, use the version with a
    // completion handler instead.
    public func synchronize() {
        frecencyQueue.sync { /* nothing to do */ }
    }
    
    public func synchronize(_ completion: @escaping () -> Void) {
        frecencyQueue.async(execute: completion)
    }
    
    // Sorts a list of search results based on the saved frecency data.
    public func sort(_ results: [SearchResult], for query: String? = nil, limitToRecents: Bool = false) -> [SearchResult] {
        var scoredResults: [ScoredResult]!
        frecencyQueue.sync {
            scoredResults = scores(for: results, query: query)
        }
        return scoredResults.sort(limitToRecents: limitToRecents)
    }
    
    public func sort(_ results: [SearchResult], for query: String? = nil, limitToRecents: Bool = false, chunkSize: Int = 10, completion: @escaping ([SearchResult]) -> Void) {
        // Score the results in chunks in the background, then combine them to
        // do final sorting. Make sure to collect the scored chunks in the
        // order that they were present in the initial array: this will let
        // us preserve the existing sort order for non-recent selections (see
        // the comment in `Array#sort(limitToRecents:)`).
        let count = results.count
        let numChunks = Int(ceil(Double(count) / Double(chunkSize)))
        var scoredChunks = [[ScoredResult]?](repeating: nil, count: numChunks)
        
        // Serialize the writes from the background, for thread safety.
        let scoredChunksQueue = DispatchQueue(label: "com.frecency.sortqueues.\(key)")
        
        let scoringGroup = DispatchGroup()
        stride(from: 0, to: count, by: chunkSize).forEach { offset in
            let chunkIndex = offset / chunkSize
            let chunk = Array(results[offset..<min(offset + chunkSize, count)])
            scoringGroup.enter()
            frecencyQueue.async {
                let scores = self.scores(for: chunk, query: query)
                scoredChunksQueue.async {
                    scoredChunks[chunkIndex] = scores
                    scoringGroup.leave()
                }
            }
        }
        
        scoringGroup.notify(queue: scoredChunksQueue) {
            let scoredResults: [ScoredResult] = scoredChunks.flatMap { $0! }
            let results = scoredResults.sort(limitToRecents: limitToRecents)
            DispatchQueue.main.async { completion(results) }
        }
    }
}

extension Array {
    func sort<SearchResult>(limitToRecents: Bool) -> [SearchResult] where Element == Frecency<SearchResult>.ScoredResult {
        // Sort recent selections by frecency. Otherwise, preserve the existing
        // sort order (e.g. that set by the search algorithm).
        let recentSelections = filter { $0.1 > 0 }
        let otherResults = filter { $0.1 == 0 }
        
        // Highest score first.
        var results = recentSelections.sorted(by: { $0.1 > $1.1 })
        if !limitToRecents { results += otherResults }
        return results.map { $0.0 }
    }
}
