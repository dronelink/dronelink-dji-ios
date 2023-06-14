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
        if let language = Dronelink.shared.language {
            // if system language is selected
            if language == "" {
                let value = DronelinkDJI.bundle.localizedString(forKey: self, value: String.LocalizationMissing, table: nil)
                //assert(value != String.LocalizationMissing, "String localization missing: \(self)")
                return value
            }

            // override language if possible
            let languagePath = Bundle.main.path(forResource: language, ofType: "lproj")
            if (languagePath != nil) {
                let bundle = Bundle(path: languagePath!)
                return NSLocalizedString(self, tableName: nil, bundle: bundle!, value: String.LocalizationMissing, comment: "")
            }
            
            
            // use english if override language isn't available
            let english = "en"
            let englishPath = Bundle.main.path(forResource: english, ofType: "lproj")
            if (englishPath != nil) {
                let bundle = Bundle(path: englishPath!)
                return NSLocalizedString(self, tableName: nil, bundle: bundle!, value: String.LocalizationMissing, comment: "")
            }
        }

        // fall back on system language if lang does not exist (perhaps because the user isn't logged in yet)
        let value = DronelinkDJI.bundle.localizedString(forKey: self, value: String.LocalizationMissing, table: nil)
        //assert(value != String.LocalizationMissing, "String localization missing: \(self)")
        return value
    }

//    var localized: String {
//        let value = DronelinkDJI.bundle.localizedString(forKey: self, value: String.LocalizationMissing, table: nil)
//        //assert(value != String.LocalizationMissing, "String localization missing: \(self)")
//        return value
//    }
    
    func escapeQuotes(_ type: String = "'") -> String {
        return self.replacingOccurrences(of: type, with: "\\\(type)")
    }
}
