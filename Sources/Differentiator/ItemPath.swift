//
//  ItemPath.swift
//  RxDataSources
//
//  Created by Krunoslav Zaher on 1/9/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import Foundation

public struct ItemPath {
    
    public let sectionIndex: Int
    public let itemIndex: Int
    
    public init(sectionIndex: Int, itemIndex: Int) {
        self.sectionIndex = sectionIndex
        self.itemIndex = itemIndex
    }
}

extension ItemPath : Equatable {
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.sectionIndex == rhs.sectionIndex
            && lhs.itemIndex == rhs.itemIndex
    }
}

extension ItemPath: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.sectionIndex.byteSwapped.hashValue)
        hasher.combine(self.itemIndex.hashValue)
    }
}
