//
//  FileUtil.swift
//  Hanami
//
//  Created by Oleg on 12/10/2022.
//

import Foundation

enum FileUtil {
    static var documentDirectory = {
        url(for: .documentDirectory)!
    }()
    static var cachesDirectory = {
        url(for: .cachesDirectory)!
    }()
    
    static var logsDirectoryURL = {
        documentDirectory.appendingPathComponent(Defaults.FilePath.logs)
    }()
    
    static var temporaryDirectory = {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }()
    
    static func url(for searchPathDirectory: FileManager.SearchPathDirectory) -> URL? {
        try? FileManager.default.url(for: searchPathDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
}
