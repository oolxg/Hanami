//
//  Defaults.swift
//  Hanami
//
//  Created by Oleg on 12/10/2022.
//

import Foundation

enum Defaults {
    enum FilePath {
        static let logs = "logs"
        static let hanamiLog = "Hanami.log"
    }
    
    enum Security {
        static let settingsConfig = "settingsConfig"
        
        static let autolockPolicy = "autolockPolicy"
        static let blurRadius = "blurRadius"
        
        // set `minBlurRadius` to 0.1 because setting it lower value causes UI bug
        static let minBlurRadius = 0.1
        static let maxBlurRadius = 15.0
        static let blurRadiusStep = 0.5
    }
    
    enum Storage {
        static let shouldUseHigherResoultionImages = "shouldUseHigherResoultionImages"
    }
}
