//
//  AnimatableSectionModel.swift
//  RxDataSources
//
//  Created by Krunoslav Zaher on 1/10/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import Foundation

public protocol AnimatableSectionModelType: SectionModelType, Identifiable & Equatable where Item: Identifiable, Item: Equatable {
    
}

public struct AnimatableSectionModel<Section: Identifiable & Equatable, ItemType: Identifiable & Equatable> {
    
    public var model: Section
    public var items: [Item]

    public init(model: Section, items: [ItemType]) {
        self.model = model
        self.items = items
    }
}

extension AnimatableSectionModel: AnimatableSectionModelType {
    
    public var id: Section.ID {
        return self.model.id
    }

    public init(original: AnimatableSectionModel, items: [ItemType]) {
        self.model = original.model
        self.items = items
    }
    
    public var hashValue: Int {
        return self.model.id.hashValue
    }
}

extension AnimatableSectionModel: Equatable where Section: Equatable {
    
    public static func == (lhs: AnimatableSectionModel, rhs: AnimatableSectionModel) -> Bool {
        return lhs.model == rhs.model
//            && lhs.items == rhs.items
    }
}

extension AnimatableSectionModel: CustomStringConvertible {

    public var description: String {
        return "HashableSectionModel(model: \"\(self.model)\", items: \(items))"
    }
}
