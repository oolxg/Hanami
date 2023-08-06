//
//  Defaults.swift
//  Hanami
//
//  Created by Oleg on 12/10/2022.
//

import Foundation

public enum Defaults {
    public enum FilePath {
        public static let logs = "logs"
        public static let hanamiLog = "Hanami.log"
    }
    
    public enum Security {
        // set `minBlurRadius` to 0.1 because setting it lower value causes UI bug
        public static let minBlurRadius = 0.1
        public static let maxBlurRadius = 20.1
        public static let blurRadiusStep = 1.0
    }
    
    public enum Search {
        public static let maxSearchHistorySize = 10
    }
    
    public enum Storage {
        public static let settingsConfig = "settingsConfig"
    }
    
    public enum Links {
        public static let bmcLink = URL(string: "https://www.buymeacoffee.com/oolxg")!
        public static let githubAvatarLink = URL(string: "https://github.com/oolxg.png")!
        public static let githubUserLink = URL(string: "https://github.com/oolxg")!
        public static let githubProjectLink = URL(string: "https://github.com/oolxg/Hanami")!
        public static let mangaDEXLink = URL(string: "https://mangadex.org")!
        public static let testFlightLink = URL(string: "https://testflight.apple.com/join/VUPzZpkc")!
        public static func mangaDexTitleLink(mangaID: UUID) -> URL {
            URL(string: "https://mangadex.org/title/\(mangaID.uuidString.lowercased())")!
        }
    }
    
    public enum Feedback {
        public static let apiURL: URL? = {
            if AppUtil.appConfiguration != .debug, var urlString = Bundle.main.infoDictionary?["API_URL"] as? String {
                urlString = "https://" + urlString
                return URL(string: urlString)
            }
            
            return nil
        }()
    }
}
