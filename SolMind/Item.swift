//
//  Item.swift
//  SolMind
//
//  Created by SAVELIEV Stanislav on 06/04/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
