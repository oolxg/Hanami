//
//  ImageFileManager.swift
//  Smuggler
//
//  Created by mk.pwnz on 15/05/2022.
//

import Foundation
import SwiftUI

class ImageFileManager {
    static let shared = ImageFileManager()
    private init () { }
    
    func saveImage(image: UIImage, withName imageName: String, inFolder folderName: String, folderType: FileManager.SearchPathDirectory = .cachesDirectory) {
        createFolderIfNeeded(withName: folderName, folderType: folderType)
        
        // get path for image
        guard let data = image.pngData(),
              let url = getURLForImage(imageName: imageName, folderName: folderName, folderType: folderType) else {
            return
        }
        
        // save image to gotten path
        do {
            try data.write(to: url)
        } catch let err {
            print("Error saving image. Image name: \(imageName). \(err.localizedDescription)")
        }
    }
    
    func getImage(withName imageName: String, from folderName: String, folderType: FileManager.SearchPathDirectory = .cachesDirectory) -> UIImage? {
        guard let url = getURLForImage(imageName: imageName, folderName: folderName, folderType: folderType),
              FileManager.default.fileExists(atPath: url.path) else {
//            print("Can't find image. Image name: \(imageName) Folder name: \(folderName)")
            return nil
        }
        
        return UIImage(contentsOfFile: url.path)
    }
    
    private func getURLForFolder(folderName: String, folderType: FileManager.SearchPathDirectory) -> URL? {
        guard let url = FileManager.default
            .urls(for: folderType, in: .userDomainMask).first else {
            return nil
        }
        
        return url.appendingPathComponent(folderName)
    }
    
    private func getURLForImage(imageName: String, folderName: String, folderType: FileManager.SearchPathDirectory) -> URL? {
        guard let url = getURLForFolder(folderName: folderName, folderType: folderType) else { return nil }
        
        return url.appendingPathComponent(imageName + ".png")
    }
    
    private func createFolderIfNeeded(withName name: String, folderType: FileManager.SearchPathDirectory) {
        guard let url = getURLForFolder(folderName: name, folderType: folderType) else { return }
        
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch let err {
                print("Error creating directory. Folder name: \(name)). \(err.localizedDescription)")
            }
        }
    }
}
