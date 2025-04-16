//
//  Item.swift
//  Glance
//
//  Created by Usman Khan on 4/16/25.
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
