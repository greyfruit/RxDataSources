//
//  FloatingPointType+Identifiable.swift
//  RxDataSources
//
//  Created by Krunoslav Zaher on 7/4/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import Foundation

public extension FloatingPoint {
    
    typealias ID = Self
    
    var id: ID {
        return self
    }
}

extension Float: Identifiable {
    
}

extension Double: Identifiable {
    
}
