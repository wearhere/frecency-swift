//
//  Emoji.swift
//  
//
//  Created by Jeffrey Wear on 5/18/20.
//

struct Emoji: Equatable, ExpressibleByStringLiteral {
    let emoji: String
    
    // There'd typically be other properties here (description, tags, etc.)
    // but they are omitted to make it simple to initialize instances in the
    // tests.
    
    init(stringLiteral value: String) {
        self.emoji = value
    }
}
