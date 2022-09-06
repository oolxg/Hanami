//
//  URL.swift
//  Smuggler
//
//  https://stackoverflow.com/a/32814710/11090054
//  Created by Leo Dabus
//

import Foundation

extension URL {
    /// check if the URL is a directory and if it is reachable
    func isDirectoryAndReachable() throws -> Bool {
        guard try resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            return false
        }
        
        return try checkResourceIsReachable()
    }
    
    /// returns total allocated size of a the directory including its subFolders or not
    func directoryTotalAllocatedSize(includingSubfolders: Bool = false) throws -> Int? {
        guard try isDirectoryAndReachable() else {
            return nil
        }
        
        if includingSubfolders {
            guard let urls = FileManager.default
                .enumerator(at: self, includingPropertiesForKeys: nil)?
                .allObjects as? [URL] else {
                return nil
            }
            
            return try urls.lazy.reduce(0) {
                (try $1.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize ?? 0) + $0
            }
        }
        
        return try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil).lazy.reduce(0) {
            (try $1.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
                .totalFileAllocatedSize ?? 0) + $0
        }
    }
    
    /// returns the directory total size on disk (in MegaBytes)
    func sizeOnDisk() -> Double? {
        guard let size = try? directoryTotalAllocatedSize(includingSubfolders: true) else {
            return nil
        }
        return Double(size) / 1000 / 1000
    }
}
