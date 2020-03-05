//
//  SectionModel.swift
//  RxDataSources
//
//  Created by Krunoslav Zaher on 6/16/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

public protocol SectionModelType {
    
    associatedtype Item

    var items: [Item] { get }

    init(original: Self, items: [Item])
}

public struct SectionModel<Section, Item>: SectionModelType {
    
    public var model: Section
    public var items: [Item]

    public init(model: Section, items: [Item]) {
        self.model = model
        self.items = items
    }
    
    public init(original: Self, items: [Item]) {
        self.model = original.model
        self.items = items
    }
}

extension SectionModel: Equatable where Section: Equatable, Item: Equatable {
    
    public static func == (lhs: SectionModel, rhs: SectionModel) -> Bool {
        return lhs.model == rhs.model
            && lhs.items == rhs.items
    }
}

extension SectionModel: CustomStringConvertible {

    public var description: String {
        return "\(self.model) > \(items)"
    }
}
