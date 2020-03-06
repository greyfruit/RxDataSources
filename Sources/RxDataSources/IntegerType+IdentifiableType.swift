//
//  IntegerType+Identifiable.swift
//  RxDataSources
//
//  Created by Krunoslav Zaher on 7/4/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import Foundation

public extension BinaryInteger {
    
    typealias ID = Self
    
    var id: ID {
        return self
    }
}

extension Int : Identifiable {
    
}

extension Int8 : Identifiable {
    
}

extension Int16 : Identifiable {
    
}

extension Int32 : Identifiable {
    
}

extension Int64 : Identifiable {
    
}


extension UInt : Identifiable {
    
}

extension UInt8 : Identifiable {
    
}

extension UInt16 : Identifiable {
    
}

extension UInt32 : Identifiable {
    
}

extension UInt64 : Identifiable {
    
}

