//
//  FileUtil.swift
//  Hanami
//
//  Created by Oleg on 12/10/2022.
//

import Foundation

public enum FileUtil {
    public static var documentDirectory = {
        url(for: .documentDirectory)!
    }()
    
    public static var cachesDirectory = {
        url(for: .cachesDirectory)!
    }()
    
    public static var logsDirectoryURL = {
        documentDirectory.appendingPathComponent(Defaults.FilePath.logs)
    }()
    
    public static var temporaryDirectory = {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }()
    
    public static func url(for searchPathDirectory: FileManager.SearchPathDirectory) -> URL? {
        try? FileManager.default.url(for: searchPathDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
}
