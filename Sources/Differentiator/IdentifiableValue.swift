//
//  IdentifiableValue.swift
//  RxDataSources
//
//  Created by Krunoslav Zaher on 1/7/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import Foundation

public struct IdentifiableValue<Value: Hashable> {
    public let value: Value
}

extension IdentifiableValue: Identifiable {
    
    public var id : Value {
        return self.value
    }
}

extension IdentifiableValue: Equatable {
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.value == rhs.value
    }
}

extension IdentifiableValue: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        return "\(self.value)"
    }

    public var debugDescription: String {
        return "\(self.value)"
    }
}
