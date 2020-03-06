//
//  Differentiator.swift
//  RxDataSources
//
//  Created by Krunoslav Zaher on 6/27/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

public enum Diff {
    
    // Generates differential changes suitable for sectioned view consumption.
    // It will not only detect changes between two states, but it will also try to compress those changes into
    // almost minimal set of changes.
    //
    // I know, I know, it's ugly :( Totally agree, but this is the only general way I could find that works 100%, and
    // avoids UITableView quirks.
    //
    // Please take into consideration that I was also convinced about 20 times that I've found a simple general
    // solution, but then UITableView falls apart under stress testing :(
    //
    // Sincerely, if somebody else would present me this 250 lines of code, I would call him a mad man. I would think
    // that there has to be a simpler solution. Well, after 3 days, I'm not convinced any more :)
    //
    // Maybe it can be made somewhat simpler, but don't think it can be made much simpler.
    //
    // The algorithm could take anywhere from 1 to 3 table view transactions to finish the updates.
    //
    //  * stage 1 - remove deleted sections and items
    //  * stage 2 - move sections into place
    //  * stage 3 - fix moved and new items
    //
    // There maybe exists a better division, but time will tell.
    //
    public static func differencesForSectionedView<Section: AnimatableSectionModelType>(initialSections: [Section], finalSections: [Section]) throws -> [Changeset<Section>] {
        
        var result: [Changeset<Section>] = []
        
        let sectionCommands = try CommandGenerator<Section>.generatorForInitialSections(initialSections, finalSections: finalSections)
        
        result.append(contentsOf: try sectionCommands.generateDeleteSectionsDeletedItemsAndUpdatedItems())
        result.append(contentsOf: try sectionCommands.generateInsertAndMoveSections())
        result.append(contentsOf: try sectionCommands.generateInsertAndMovedItems())
        
        return result
    }
}

extension Diff {
    
    private typealias ItemCache<Item> = ContiguousArray<ContiguousArray<Item>>
    private typealias AssociatedData = (initialItemData: ItemCache<ItemAssociatedData>, finalItemData: ItemCache<ItemAssociatedData>)
    
    private struct CommandGenerator<Section: AnimatableSectionModelType> {
        
        typealias Item = Section.Item
        
        let initialSections: [Section]
        let finalSections: [Section]
        
        let initialSectionData: ContiguousArray<SectionAssociatedData>
        let finalSectionData: ContiguousArray<SectionAssociatedData>
        
        let initialItemData: ContiguousArray<ContiguousArray<ItemAssociatedData>>
        let finalItemData: ContiguousArray<ContiguousArray<ItemAssociatedData>>
        
        let initialItemCache: ContiguousArray<ContiguousArray<Item>>
        let finalItemCache: ContiguousArray<ContiguousArray<Item>>
        
        static func generatorForInitialSections(_ initialSections: [Section], finalSections: [Section]) throws -> CommandGenerator<Section> {
            
            let (initialSectionData, finalSectionData) = try Self.calculateSectionUpdates(
                initialSections: initialSections,
                finalSections: finalSections
            )
            
            let initialItemCache = ContiguousArray(initialSections.map {
                ContiguousArray($0.items)
            })
            
            let finalItemCache = ContiguousArray(finalSections.map {
                ContiguousArray($0.items)
            })
            
            let (initialItemData, finalItemData) = try Self.calculateItemUpdates(
                initialItemCache: initialItemCache,
                finalItemCache: finalItemCache,
                initialSectionData: initialSectionData,
                finalSectionData: finalSectionData
            )
            
            return CommandGenerator<Section>(
                initialSections: initialSections,
                finalSections: finalSections,
                initialSectionData: initialSectionData,
                finalSectionData: finalSectionData,
                initialItemData: initialItemData,
                finalItemData: finalItemData,
                initialItemCache: initialItemCache,
                finalItemCache: finalItemCache
            )
        }
        
        private static func calculateAssociatedData<Item: Identifiable>(initialItemCache: ItemCache<Item>, finalItemCache: ItemCache<Item>) throws -> AssociatedData {
            
            typealias Identity = Item.ID
            
            let totalInitialItems = initialItemCache.map { $0.count }.reduce(0, +)
            
            var initialIdentities: ContiguousArray<Identity> = ContiguousArray()
            var initialItemPaths: ContiguousArray<ItemPath> = ContiguousArray()
            
            initialIdentities.reserveCapacity(totalInitialItems)
            initialItemPaths.reserveCapacity(totalInitialItems)
            
            for (i, items) in initialItemCache.enumerated() {
                for j in 0 ..< items.count {
                    let item = items[j]
                    initialIdentities.append(item.id)
                    initialItemPaths.append(ItemPath(sectionIndex: i, itemIndex: j))
                }
            }
            
            var initialItemData = ContiguousArray(initialItemCache.map { items in
                return ContiguousArray<ItemAssociatedData>(repeating: ItemAssociatedData.initial, count: items.count)
            })
            
            var finalItemData = ContiguousArray(finalItemCache.map { items in
                return ContiguousArray<ItemAssociatedData>(repeating: ItemAssociatedData.initial, count: items.count)
            })
            
            try initialIdentities.withUnsafeBufferPointer { (identitiesBuffer: UnsafeBufferPointer<Identity>) -> Void in
                
                var dictionary: [OptimizedIdentity<Identity>: Int] = Dictionary(minimumCapacity: totalInitialItems * 2)
                
                for i in 0..<initialIdentities.count {
                    let identityPointer = identitiesBuffer.baseAddress!.advanced(by: i)
                    
                    let key = OptimizedIdentity(identityPointer)
                    
                    if let existingValueItemPathIndex = dictionary[key] {
                        let itemPath = initialItemPaths[existingValueItemPathIndex]
                        let item = initialItemCache[itemPath.sectionIndex][itemPath.itemIndex]
                        #if DEBUG
                        print("Item \(item) has already been indexed at \(itemPath)" )
                        #endif
                        throw Error.duplicateItem(item: item)
                    }
                    
                    dictionary[key] = i
                }
                
                for (i, items) in finalItemCache.enumerated() {
                    for j in 0 ..< items.count {
                        let item = items[j]
                        var identity = item.id
                        let key = OptimizedIdentity(&identity)
                        guard let initialItemPathIndex = dictionary[key] else {
                            continue
                        }
                        let itemPath = initialItemPaths[initialItemPathIndex]
                        if initialItemData[itemPath.sectionIndex][itemPath.itemIndex].moveIndex != nil {
                            throw Error.duplicateItem(item: item)
                        }
                        
                        initialItemData[itemPath.sectionIndex][itemPath.itemIndex].moveIndex = ItemPath(sectionIndex: i, itemIndex: j)
                        finalItemData[i][j].moveIndex = itemPath
                    }
                }
            }
            
            return AssociatedData(
                initialItemData,
                finalItemData
            )
        }
        
        static func calculateSectionUpdates(initialSections: [Section], finalSections: [Section]) throws -> (ContiguousArray<SectionAssociatedData>, ContiguousArray<SectionAssociatedData>) {
            
            let initialSectionIndexes = try Diff.indexSections(initialSections)
            
            var initialSectionData = ContiguousArray<SectionAssociatedData>(repeating: SectionAssociatedData.initial, count: initialSections.count)
            var finalSectionData = ContiguousArray<SectionAssociatedData>(repeating: SectionAssociatedData.initial, count: finalSections.count)
            
            for (i, section) in finalSections.enumerated() {
                
                finalSectionData[i].itemCount = finalSections[i].items.count
                
                guard let initialSectionIndex = initialSectionIndexes[section.id] else {
                    continue
                }
                
                if initialSectionData[initialSectionIndex].moveIndex != nil {
                    throw Error.duplicateSection(section: section)
                }
                
                initialSectionData[initialSectionIndex].moveIndex = i
                finalSectionData[i].moveIndex = initialSectionIndex
            }
            
            // deleted sections
            var sectionIndexAfterDelete = 0
            for (i, section) in initialSections.enumerated() {
                
                initialSectionData[i].itemCount = section.items.count
                
                if initialSectionData[i].moveIndex == nil {
                    initialSectionData[i].event = .deleted
                    continue
                }
                
                initialSectionData[i].indexAfterDelete = sectionIndexAfterDelete
                sectionIndexAfterDelete += 1
            }
            
            // moved sections
            let findNextUntouchedOldIndex = { (initialSearchIndex: Int?) -> Int? in
                
                guard var i = initialSearchIndex else {
                    return nil
                }
                
                while i < initialSections.count {
                    
                    if initialSectionData[i].event == .untouched {
                        return i
                    }
                    
                    i += 1
                }
                
                return nil
            }
            
            var untouchedOldIndex: Int? = 0
            for i in 0..<finalSections.count {
                
                untouchedOldIndex = findNextUntouchedOldIndex(untouchedOldIndex)
                
                if let oldSectionIndex = finalSectionData[i].moveIndex {
                    
                    let moveEvent: EditEvent = oldSectionIndex == untouchedOldIndex
                        ? .movedAutomatically
                        : .moved
                    
                    finalSectionData[i].event = moveEvent
                    initialSectionData[oldSectionIndex].event = moveEvent
                    
                } else {
                    finalSectionData[i].event = .inserted
                }
            }
            
            // updated sections
            for (i, finalSection) in finalSections.enumerated() {
                
                guard [EditEvent.untouched, .movedAutomatically].contains(finalSectionData[i].event) else {
                    continue
                }
                
                if initialSectionIndexes[finalSection.id] == i, finalSection != initialSections[i] {
                    initialSectionData[i].event = .updated
                    finalSectionData[i].event = .updated
                }
            }
            
            return (initialSectionData, finalSectionData)
        }
        
        static func calculateItemUpdates(
            initialItemCache: ContiguousArray<ContiguousArray<Item>>,
            finalItemCache: ContiguousArray<ContiguousArray<Item>>,
            initialSectionData: ContiguousArray<SectionAssociatedData>,
            finalSectionData: ContiguousArray<SectionAssociatedData>) throws
            -> (ContiguousArray<ContiguousArray<ItemAssociatedData>>, ContiguousArray<ContiguousArray<ItemAssociatedData>>) {
                
                var (initialItemData, finalItemData) = try Self.calculateAssociatedData(
                    initialItemCache: initialItemCache,
                    finalItemCache: finalItemCache
                )
                
                let findNextUntouchedOldIndex = { (initialSectionIndex: Int, initialSearchIndex: Int?) -> Int? in
                    guard var i2 = initialSearchIndex else {
                        return nil
                    }
                    
                    while i2 < initialSectionData[initialSectionIndex].itemCount {
                        if initialItemData[initialSectionIndex][i2].event == .untouched {
                            return i2
                        }
                        
                        i2 += 1
                    }
                    
                    return nil
                }
                
                // first mark deleted items
                for i in 0 ..< initialItemCache.count {
                    guard initialSectionData[i].moveIndex != nil else {
                        continue
                    }
                    
                    var indexAfterDelete = 0
                    for j in 0 ..< initialItemCache[i].count {
                        
                        guard initialSectionData[i].event != .updated else {
                            continue
                        }
                        
                        guard let finalIndexPath = initialItemData[i][j].moveIndex else {
                            initialItemData[i][j].event = .deleted
                            continue
                        }
                        
                        // from this point below, section has to be move type because it's initial and not deleted
                        
                        // because there is no move to inserted section
                        if finalSectionData[finalIndexPath.sectionIndex].event == .inserted {
                            initialItemData[i][j].event = .deleted
                            continue
                        }
                        
                        initialItemData[i][j].indexAfterDelete = indexAfterDelete
                        indexAfterDelete += 1
                    }
                }
                
                // mark moved or moved automatically
                for i in 0 ..< finalItemCache.count {
                    guard let originalSectionIndex = finalSectionData[i].moveIndex else {
                        continue
                    }
                    
                    var untouchedIndex: Int? = 0
                    for j in 0 ..< finalItemCache[i].count {
                        untouchedIndex = findNextUntouchedOldIndex(originalSectionIndex, untouchedIndex)
                        
                        guard finalSectionData[i].event != .updated else {
                            continue
                        }
                        
                        guard let originalIndex = finalItemData[i][j].moveIndex else {
                            finalItemData[i][j].event = .inserted
                            continue
                        }
                        
                        // In case trying to move from deleted section, abort, otherwise it will crash table view
                        if initialSectionData[originalIndex.sectionIndex].event == .deleted {
                            finalItemData[i][j].event = .inserted
                            continue
                        }
                            // original section can't be inserted
                        else if initialSectionData[originalIndex.sectionIndex].event == .inserted {
                            try precondition(false, "New section in initial sections, that is wrong")
                        }
                        
                        let initialSectionEvent = initialSectionData[originalIndex.sectionIndex].event
                        try precondition(initialSectionEvent == .moved || initialSectionEvent == .movedAutomatically || initialSectionEvent == .updated, "Section not moved")
                        
                        let eventType = originalIndex == ItemPath(sectionIndex: originalSectionIndex, itemIndex: untouchedIndex ?? -1)
                            ? EditEvent.movedAutomatically : EditEvent.moved
                        
                        initialItemData[originalIndex.sectionIndex][originalIndex.itemIndex].event = eventType
                        finalItemData[i][j].event = eventType
                    }
                }
                
                return (initialItemData, finalItemData)
        }
        
        func generateDeleteSectionsDeletedItemsAndUpdatedItems() throws -> [Changeset<Section>] {
            
            var deletedSections = [Int]()
            var updatedSections = [Int]()
            
            var deletedItems = [ItemPath]()
            var updatedItems = [ItemPath]()
            
            var afterDeleteState = [Section]()
            
            // mark deleted items {
            // 1rst stage again (I know, I know ...)
            for (i, initialItems) in initialItemCache.enumerated() {
                let event = initialSectionData[i].event
                
                // Deleted section will take care of deleting child items.
                // In case of moving an item from deleted section, tableview will
                // crash anyway, so this is not limiting anything.
                if event == .deleted {
                    deletedSections.append(i)
                    continue
                }
                
                if event == .updated {
                    updatedSections.append(i)
                    afterDeleteState.append(try Section(safeOriginal: finalSections[i], safeItems: finalSections[i].items))
                    continue
                }
                
                var afterDeleteItems: [Section.Item] = []
                for j in 0 ..< initialItems.count {
                    let event = initialItemData[i][j].event
                    switch event {
                    case .deleted:
                        deletedItems.append(ItemPath(sectionIndex: i, itemIndex: j))
                    case .moved, .movedAutomatically:
                        let finalItemIndex = try initialItemData[i][j].moveIndex.unwrap()
                        let finalItem = finalItemCache[finalItemIndex.sectionIndex][finalItemIndex.itemIndex]
                        if finalItem != initialSections[i].items[j] {
                            updatedItems.append(ItemPath(sectionIndex: i, itemIndex: j))
                        }
                        afterDeleteItems.append(finalItem)
                    default:
                        try precondition(false, "Unhandled case")
                    }
                }
                
                afterDeleteState.append(try Section(safeOriginal: initialSections[i], safeItems: afterDeleteItems))
            }
            
            if deletedItems.isEmpty && deletedSections.isEmpty && updatedItems.isEmpty && updatedSections.isEmpty {
                return []
            }
            
            return [
                Changeset(
                    finalSections: afterDeleteState,
                    deletedSections: deletedSections,
                    updatedSections: updatedSections,
                    deletedItems: deletedItems,
                    updatedItems: updatedItems
                )
            ]
        }
        
        func generateInsertAndMoveSections() throws -> [Changeset<Section>] {
            
            var movedSections = [(from: Int, to: Int)]()
            var insertedSections = [Int]()
            
            for i in 0 ..< initialSections.count {
                switch initialSectionData[i].event {
                case .updated:
                    break
                case .deleted:
                    break
                case .moved:
                    movedSections.append((from: try initialSectionData[i].indexAfterDelete.unwrap(), to: try initialSectionData[i].moveIndex.unwrap()))
                case .movedAutomatically:
                    break
                default:
                    try precondition(false, "Unhandled case in initial sections")
                }
            }
            
            for i in 0 ..< finalSections.count {
                switch finalSectionData[i].event {
                case .inserted:
                    insertedSections.append(i)
                default:
                    break
                }
            }
            
            if insertedSections.isEmpty && movedSections.isEmpty {
                return []
            }
            
            // sections should be in place, but items should be original without deleted ones
            let sectionsAfterChange: [Section] = try self.finalSections.enumerated().map { i, s -> Section in
                let event = self.finalSectionData[i].event
                
                if event == .inserted {
                    // it's already set up
                    return s
                }
                else if event == .moved || event == .movedAutomatically {
                    let originalSectionIndex = try finalSectionData[i].moveIndex.unwrap()
                    let originalSection = initialSections[originalSectionIndex]
                    
                    var items: [Section.Item] = []
                    items.reserveCapacity(originalSection.items.count)
                    let itemAssociatedData = self.initialItemData[originalSectionIndex]
                    for j in 0 ..< originalSection.items.count {
                        let initialData = itemAssociatedData[j]
                        
                        guard initialData.event != .deleted else {
                            continue
                        }
                        
                        guard let finalIndex = initialData.moveIndex else {
                            try precondition(false, "Item was moved, but no final location.")
                            continue
                        }
                        
                        items.append(finalItemCache[finalIndex.sectionIndex][finalIndex.itemIndex])
                    }
                    
                    let modifiedSection = try Section(safeOriginal: s, safeItems: items)
                    
                    return modifiedSection
                }
                else {
                    try precondition(false, "This is weird, this shouldn't happen")
                    return s
                }
            }
            
            return [
                Changeset(
                    finalSections: sectionsAfterChange,
                    insertedSections:  insertedSections,
                    movedSections: movedSections
                )
            ]
        }
        
        func generateInsertAndMovedItems() throws -> [Changeset<Section>] {
            
            var insertedItems = [ItemPath]()
            var movedItems = [(from: ItemPath, to: ItemPath)]()
            
            // mark new and moved items
            // 3rd stage
            for i in 0 ..< finalSections.count {
                let finalSection = finalSections[i]
                
                let sectionEvent = finalSectionData[i].event
                // new and deleted sections cause reload automatically
                if sectionEvent != .moved && sectionEvent != .movedAutomatically {
                    continue
                }
                
                for j in 0 ..< finalSection.items.count {
                    let currentItemEvent = finalItemData[i][j].event
                    
                    try precondition(currentItemEvent != .untouched, "Current event is not untouched")
                    
                    let event = finalItemData[i][j].event
                    
                    switch event {
                    case .inserted:
                        insertedItems.append(ItemPath(sectionIndex: i, itemIndex: j))
                    case .moved:
                        let originalIndex = try finalItemData[i][j].moveIndex.unwrap()
                        let finalSectionIndex = try initialSectionData[originalIndex.sectionIndex].moveIndex.unwrap()
                        let moveFromItemWithIndex = try initialItemData[originalIndex.sectionIndex][originalIndex.itemIndex].indexAfterDelete.unwrap()
                        
                        let moveCommand = (
                            from: ItemPath(sectionIndex: finalSectionIndex, itemIndex: moveFromItemWithIndex),
                            to: ItemPath(sectionIndex: i, itemIndex: j)
                        )
                        movedItems.append(moveCommand)
                    default:
                        break
                    }
                }
            }
            
            if insertedItems.isEmpty && movedItems.isEmpty {
                return []
            }
            
            return [
                Changeset(
                    finalSections: finalSections,
                    insertedItems: insertedItems,
                    movedItems: movedItems
                )
            ]
        }
    }
}

extension Diff {
    
    public enum Error : Swift.Error, CustomDebugStringConvertible {
        
        case duplicateItem(item: Any)
        case duplicateSection(section: Any)
        case invalidInitializerImplementation(section: Any, expectedItems: Any, expectedIdentifier: Any)
        
        public var debugDescription: String {
            switch self {
            case let .duplicateItem(item):
                return "Duplicate item \(item)"
            case let .duplicateSection(section):
                return "Duplicate section \(section)"
            case let .invalidInitializerImplementation(section, expectedItems, expectedIdentifier):
                return """
                Wrong initializer implementation for: \(section)
                Expected it should return items: \(expectedItems)
                Expected it should have id: \(expectedIdentifier)
                """
            }
        }
    }
    
    private enum EditEvent : CustomDebugStringConvertible {
        
        case inserted               // can't be found in old sections
        case insertedAutomatically  // Item inside section being inserted
        case deleted                // Was in old, not in new, in it's place is something "not new" :(, otherwise it's Updated
        case deletedAutomatically   // Item inside section that is being deleted
        case moved                  // same item, but was on different index, and needs explicit move
        case movedAutomatically     // don't need to specify any changes for those rows
        case updated
        case untouched
        
        var debugDescription: String {
            switch self {
            case .inserted:
                return "Inserted"
            case .insertedAutomatically:
                return "InsertedAutomatically"
            case .deleted:
                return "Deleted"
            case .deletedAutomatically:
                return "DeletedAutomatically"
            case .moved:
                return "Moved"
            case .movedAutomatically:
                return "MovedAutomatically"
            case .updated:
                return "Updated"
            case .untouched:
                return "Untouched"
            }
        }
    }
    
    private struct SectionAssociatedData: CustomDebugStringConvertible {
        
        var event: EditEvent
        var indexAfterDelete: Int?
        var moveIndex: Int?
        var itemCount: Int
        
        var debugDescription: String {
            return "\(self.event), \(String(describing: self.indexAfterDelete))"
        }
        
        static var initial: SectionAssociatedData {
            return SectionAssociatedData(event: .untouched, indexAfterDelete: nil, moveIndex: nil, itemCount: 0)
        }
    }
    
    private struct ItemAssociatedData: CustomDebugStringConvertible {
        
        var event: EditEvent
        var indexAfterDelete: Int?
        var moveIndex: ItemPath?
        
        var debugDescription: String {
            return "\(event) \(String(describing: indexAfterDelete))"
        }
        
        static var initial : ItemAssociatedData {
            return ItemAssociatedData(event: .untouched, indexAfterDelete: nil, moveIndex: nil)
        }
    }
    
    private struct OptimizedIdentity<Identity: Hashable>: Hashable {
        
        let identity: UnsafePointer<Identity>
        let cachedHashValue: Int
        
        init(_ identity: UnsafePointer<Identity>) {
            self.identity = identity
            self.cachedHashValue = identity.pointee.hashValue
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(self.cachedHashValue)
        }
        
        static func == (lhs: OptimizedIdentity<Identity>, rhs: OptimizedIdentity<Identity>) -> Bool {
            return lhs.hashValue == rhs.hashValue
                && lhs.identity.distance(to: rhs.identity) != 0
                && lhs.identity.pointee == rhs.identity.pointee
        }
    }
    
    private static func indexSections<Section: AnimatableSectionModelType>(_ sections: [Section]) throws -> [Section.ID : Int] {
        
        var indexedSections: [Section.ID : Int] = [:]
        
        for (i, section) in sections.enumerated() {
            guard indexedSections[section.id] == nil else {
                #if DEBUG
                if indexedSections[section.id] != nil {
                    print("Section \(section) has already been indexed at \(indexedSections[section.id]!)")
                }
                #endif
                throw Error.duplicateSection(section: section)
            }
            indexedSections[section.id] = i
        }
        
        return indexedSections
    }
}

fileprivate extension AnimatableSectionModelType {
    
    init(safeOriginal: Self, safeItems: [Item]) throws {
        self.init(original: safeOriginal, items: safeItems)
        
        guard self.items == safeItems && self.id == safeOriginal.id else {
            throw Diff.Error.invalidInitializerImplementation(section: self, expectedItems: safeItems, expectedIdentifier: safeOriginal.id)
        }
    }
}
