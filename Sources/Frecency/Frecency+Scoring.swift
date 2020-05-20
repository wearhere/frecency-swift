//
//  Frecency+Scoring.swift
//  
//
//  Created by Jeffrey Wear on 5/18/20.
//

import Foundation

extension Frecency {
    typealias ScoredResult = (SearchResult, Double)
    
    // WARNING: This function must be called from `frecencyQueue`.
    internal func scores(for results: [SearchResult], query: String? = nil) -> [ScoredResult] {
        let now = Date().timeIntervalSince1970

        return results.map { result in
            let resultId = resultIdentifier.id(result)

            // Try calculating frecency score in order of weight.
            if let query = query {
                // Try calculating frecency score by exact query match.
                if let selection = frecency.queries[query]?[resultId] {
                    let score = weights.exactQuery * selection.score(at: now)
                    if score > 0 { return (result, score) }
                }
                
                // Try calculating frecency score by sub-query match.
                let fullQueries = frecency.queries.keys.filter { query.isSubQuery(of: $0) }
                for fullQuery in fullQueries {
                    if let selection = frecency.queries[fullQuery]?[resultId] {
                        let score = weights.subQuery * selection.score(at: now)
                        if score > 0 { return (result, score) }
                    }
                }
            }
            
            // Try calculating frecency score by ID.
            if let selection = frecency.selections[resultId] {
                let score = weights.recentSelection * selection.score(at: now)
                if score > 0 { return (result, score) }
            }
            
            return (result, 0)
        }
    }
}

extension Selection {
    func score(at time: TimeInterval) -> Double {
        guard !selectedAt.isEmpty else { return 0 }
        
        let hour: TimeInterval = 60 * 60;
        let day: TimeInterval = 24 * hour;
        
        let totalScore = selectedAt.reduce(0) { score, timestamp in
            if timestamp >= time - 3 * hour { return score + 100 }
            if timestamp >= time - day { return score + 80 }
            if timestamp >= time - 3 * day { return score + 60 }
            if timestamp >= time - 7 * day { return score + 30 }
            if timestamp >= time - 14 * day { return score + 10 }
            return score
        }
        
        return Double(timesSelected) * (Double(totalScore) / Double(selectedAt.count));
    }
}

extension String {
   /**
    * Performs a by-word prefix match to determine if a string is a sub query
    * of a given query. For example:
    * - 'de tea' is a subquery of 'design team' because 'de' is a substring of 'design'
    *   and 'tea' is a substring of 'team'.
    * - 'team desi' is a subquery of 'design team' because we don't consider order.
    */
    func isSubQuery(of query: String) -> Bool {
        // Split the string into words and order reverse-alphabetically.
        let searchStrings = lowercased().split(separator: " ").sorted(by: >)
        var queryStrings = query.lowercased().split(separator: " ").sorted(by: >)
        
        // Make sure each search string is a prefix of at least 1 word in the query strings.
        for searchString in searchStrings {
            guard let matchIndex = queryStrings.firstIndex(where: { queryString in
                queryString.starts(with: searchString)
            }) else {
                return false
            }
            
            // Remove the matched query string so we don't match it again.
            queryStrings.remove(at: matchIndex)
        }
        
        return true;
    }
}
