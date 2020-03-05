//
//  Optional+Extensions.swift
//  RxDataSources
//
//  Created by Krunoslav Zaher on 1/8/16.
//  Copyright © 2016 Krunoslav Zaher. All rights reserved.
//

import Foundation

extension Optional {
    
    func unwrap() throws -> Wrapped {
        switch self {
        case .some(let wrapped):
            return wrapped
        case .none:
            debugFatalError("Error during unwrapping optional"); throw DifferentiatorError.unwrappingOptional
        }
    }
}
