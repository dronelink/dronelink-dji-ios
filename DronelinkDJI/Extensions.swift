//
//  Extensions.swift
//  DronelinkDJI
//
//  Created by Jim McAndrew on 10/28/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import Foundation
import DronelinkCore
import DJISDK

extension String {
    private static let LocalizationMissing = "MISSING STRING LOCALIZATION"
    
    var localized: String {
        let value = DronelinkDJI.bundle.localizedString(forKey: self, value: String.LocalizationMissing, table: nil)
        //assert(value != String.LocalizationMissing, "String localization missing: \(self)")
        return value
    }
    
    func escapeQuotes(_ type: String = "'") -> String {
        return self.replacingOccurrences(of: type, with: "\\\(type)")
    }
}
