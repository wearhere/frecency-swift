//
//  FrecencyData.swift
//  
//  Created by Jeffrey Wear on 5/17/20.
//

import Foundation

struct FrecencyData: Codable, Equatable {
    // Stores information about which results the user selected based on
    // their search query and how frequently they selected these results.
    private(set) var queries: [Query: Selections] = [:]
    
    // Stores information about how often a particular result has been chosen
    // regardless of query. Use case:
    // 1. User searches "brad" and selects "brad vogel" very often.
    // 2. User searches "vogel" and "brad vogel" appears in the list of search results.
    // 3. Even though the user has never searched "vogel", we still want "brad vogel"
    //    to rank higher because "brad vogel" has been selected very often.
    private(set) var selections: Selections = [:]
    
    // Cache of recently selected IDs (ordered from most to least recent). When an ID is
    // selected we'll add or shift the ID to the front. When this list exceeds a certain
    // limit, we'll remove the last ID and remove all frecency data for this ID.
    private(set) var recentSelections: RecentSelections = []
    
    // Records that the user has selected a result.
    mutating func select<SearchResult>(_ id: SelectionId, for query: Query?, time: TimeInterval, limits: Frecency<SearchResult>.StorageLimits) {
        if let query = query {
            // Record that this result was selected for the particular query.
            if queries[query] == nil { queries[query] = [:] }
            queries[query]?.select(id, time: time, timestampsLimit: limits.timestamps)
        }
        
        // Record that the result was selected regardless of query.
        selections.select(id, time: time, timestampsLimit: limits.timestamps)
        
        if let expiredId = recentSelections.select(id, limit: limits.recentSelections) {
            queries = queries.compactMapValues {
                var selections = $0
                selections.removeValue(forKey: expiredId)
                return selections.isEmpty ? nil : selections
            }
            selections.removeValue(forKey: expiredId)
        }
    }
}

typealias Query = String
typealias SelectionId = String

struct Selection: Codable, Equatable {
    // Total times this result was chosen.
    fileprivate(set) var timesSelected: Int
    
    // The timestamps of the most recent selections, which will be used to
    // calculate relevance scores for each result.
    fileprivate(set) var selectedAt: [TimeInterval]
}

typealias RecentSelections = [SelectionId]
fileprivate extension RecentSelections {
    mutating func select(_ id: SelectionId, limit: Int) -> String? {
        // If we already contained the selected ID, shift it to the front.
        if let index = firstIndex(of: id) {
            remove(at: index)
            insert(id, at: 0)
            return nil
        }

        // Otherwise add the selected ID to the front of the list.
        insert(id, at: 0)
        
        guard count > limit else { return nil }
        
        // If the number of recent selections has gone over the limit, we'll remove
        // the least recently used ID.
        return removeLast()
    }
}

typealias Selections = [SelectionId: Selection]
fileprivate extension Selections {
    mutating func select(_ id: SelectionId, time: TimeInterval, timestampsLimit: Int) {
        if var previousSelection = self[id] {
            previousSelection.timesSelected += 1;
            previousSelection.selectedAt.append(time);
            if previousSelection.selectedAt.count > timestampsLimit {
                previousSelection.selectedAt.removeFirst()
            }
            self[id] = previousSelection
        } else {
            self[id] = Selection(timesSelected: 1, selectedAt: [time])
        }
    }
}
