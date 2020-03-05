//
//  UI+SectionedViewType.swift
//  RxDataSources
//
//  Created by Krunoslav Zaher on 6/27/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import UIKit
import Foundation
import Differentiator

extension UITableView : SectionedViewType {
  
    public func insertItemsAtIndexPaths(_ paths: [IndexPath], animationStyle: UITableView.RowAnimation) {
        self.insertRows(at: paths, with: animationStyle)
    }
    
    public func deleteItemsAtIndexPaths(_ paths: [IndexPath], animationStyle: UITableView.RowAnimation) {
        self.deleteRows(at: paths, with: animationStyle)
    }
    
    public func moveItemAtIndexPath(_ from: IndexPath, to: IndexPath) {
        self.moveRow(at: from, to: to)
    }
    
    public func reloadItemsAtIndexPaths(_ paths: [IndexPath], animationStyle: UITableView.RowAnimation) {
        self.reloadRows(at: paths, with: animationStyle)
    }
    
    public func insertSections(_ sections: [Int], animationStyle: UITableView.RowAnimation) {
        self.insertSections(IndexSet(sections), with: animationStyle)
    }
    
    public func deleteSections(_ sections: [Int], animationStyle: UITableView.RowAnimation) {
        self.deleteSections(IndexSet(sections), with: animationStyle)
    }
    
    public func moveSection(_ from: Int, to: Int) {
        self.moveSection(from, toSection: to)
    }
    
    public func reloadSections(_ sections: [Int], animationStyle: UITableView.RowAnimation) {
        self.reloadSections(IndexSet(sections), with: animationStyle)
    }
}

extension UICollectionView : SectionedViewType {
    
    public func insertItemsAtIndexPaths(_ paths: [IndexPath], animationStyle: UITableView.RowAnimation) {
        self.insertItems(at: paths)
    }
    
    public func deleteItemsAtIndexPaths(_ paths: [IndexPath], animationStyle: UITableView.RowAnimation) {
        self.deleteItems(at: paths)
    }

    public func moveItemAtIndexPath(_ from: IndexPath, to: IndexPath) {
        self.moveItem(at: from, to: to)
    }
    
    public func reloadItemsAtIndexPaths(_ paths: [IndexPath], animationStyle: UITableView.RowAnimation) {
        self.reloadItems(at: paths)
    }
    
    public func insertSections(_ sections: [Int], animationStyle: UITableView.RowAnimation) {
        self.insertSections(IndexSet(sections))
    }
    
    public func deleteSections(_ sections: [Int], animationStyle: UITableView.RowAnimation) {
        self.deleteSections(IndexSet(sections))
    }
    
    public func moveSection(_ from: Int, to: Int) {
        self.moveSection(from, toSection: to)
    }
    
    public func reloadSections(_ sections: [Int], animationStyle: UITableView.RowAnimation) {
        self.reloadSections(IndexSet(sections))
    }
}

public protocol SectionedViewType {
    
    func insertItemsAtIndexPaths(_ paths: [IndexPath], animationStyle: UITableView.RowAnimation)
    func deleteItemsAtIndexPaths(_ paths: [IndexPath], animationStyle: UITableView.RowAnimation)
    func reloadItemsAtIndexPaths(_ paths: [IndexPath], animationStyle: UITableView.RowAnimation)
    func moveItemAtIndexPath(_ from: IndexPath, to: IndexPath)
    
    func insertSections(_ sections: [Int], animationStyle: UITableView.RowAnimation)
    func deleteSections(_ sections: [Int], animationStyle: UITableView.RowAnimation)
    func reloadSections(_ sections: [Int], animationStyle: UITableView.RowAnimation)
    func moveSection(_ from: Int, to: Int)
}

extension SectionedViewType {
    
    public func batchUpdates<Section>(_ changes: Changeset<Section>, animationConfiguration: AnimationConfiguration) {
        
        deleteSections(changes.deletedSections, animationStyle: animationConfiguration.deleteAnimation)
        
        insertSections(changes.insertedSections, animationStyle: animationConfiguration.insertAnimation)
        
        reloadSections(changes.updatedSections, animationStyle: animationConfiguration.reloadAnimation)
        
        for (from, to) in changes.movedSections {
            moveSection(from, to: to)
        }
        
        deleteItemsAtIndexPaths(
            changes.deletedItems.map { IndexPath(item: $0.itemIndex, section: $0.sectionIndex) },
            animationStyle: animationConfiguration.deleteAnimation
        )
        insertItemsAtIndexPaths(
            changes.insertedItems.map { IndexPath(item: $0.itemIndex, section: $0.sectionIndex) },
            animationStyle: animationConfiguration.insertAnimation
        )
        reloadItemsAtIndexPaths(
            changes.updatedItems.map { IndexPath(item: $0.itemIndex, section: $0.sectionIndex) },
            animationStyle: animationConfiguration.reloadAnimation
        )
        
        for (from, to) in changes.movedItems {
            moveItemAtIndexPath(
                IndexPath(item: from.itemIndex, section: from.sectionIndex),
                to: IndexPath(item: to.itemIndex, section: to.sectionIndex)
            )
        }
    }
}
