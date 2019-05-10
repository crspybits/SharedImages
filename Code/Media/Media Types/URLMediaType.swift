//
//  URLMediaType.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/28/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SMCoreLib

extension URLMediaObject: MediaType {
    var mediaTypeSize: MediaTypeSize {return .fit}
    var originalSize: CGSize? {
        return nil
    }
    
    func checkForReadProblem(mediaData: MediaData) -> Bool {
        // TODO: Need to read file and see if have a read problem.
        return false
    }
    
    func setup(mediaData: MediaData) {
    }
    
    // Also removes associated discussions.
    static func removeLocalMedia(uuid:String) -> Bool {
        return FileMediaObject.remove(uuid: uuid)
    }
    
    struct URLFileContents {
        let url: URL
        
        // Title is optional because it's possible a title wasn't obtained in the LinkPreview
        let title: String?
        
        enum ImageType: String {
            case icon
            case large
        }
        
        // Optional because there may have been no image obtained in the LinkPreview.
        let imageType:ImageType?
    }
    
    private static let maxNumberLinesInURLFile = 4
    private static let minNumberLinesInURLFile = 2
    private static let URLKey = "URL"
    private static let titleKey = "TITLE"
    private static let imageTypeKey = "IMAGETYPE"

    // Creates a local .url file. Returns nil iff fails.
    static func createLocalURLFile(contents: URLFileContents) -> SMRelativeLocalURL? {
        let localFileURL = Files.newURLForURLFile()
        
        // The format of .url files seems weakly defined. I'm extending it with a `TITLE`. Hopefully these files can (continue to) launch both on MacOS and Windows. No clue about Linux systems...
        // e.g., see http://www.lyberty.com/encyc/articles/tech/dot_url_format_-_an_unofficial_guide.html
        var mediaURLContents =
            "[InternetShortcut]\n" +
            "\(URLKey)=\(contents.url)\n"
        
        if let title = contents.title {
            mediaURLContents += "\(titleKey)=\(title)\n"
        }
        
        if let imageType = contents.imageType {
            mediaURLContents += "\(imageTypeKey)=\(imageType.rawValue)\n"
        }
        
        guard let data = mediaURLContents.data(using: .utf8) else {
            Log.error("Could not convert url data into string.")
            return nil
        }
        
        do {
            try data.write(to: localFileURL as URL)
        }
        catch (let error) {
            Log.error("Could not write URL media to file: \(error)")
            return nil
        }
        
        return localFileURL
    }
    
    static func parseURLFile(localURLFile: URL) -> URLFileContents? {
        guard let fileData = try? Data(contentsOf: localURLFile) else {
            return nil
        }
        
        guard let fileString = String(data: fileData, encoding: .utf8) else {
            return nil
        }
        
        var lines = fileString.split(separator: "\n")
        
        guard lines.count >= minNumberLinesInURLFile,
            lines.count <= maxNumberLinesInURLFile else {
            return nil
        }
        
        // Remove the "[InternetShortcut]"
        lines.removeFirst()
        
        var contents = [String: String]()
        for line in lines {
            let result = line.split(separator: "=", maxSplits: 1).map({String($0)})
            guard result.count == 2 else {
                return nil
            }
            
            contents[result[0]] = result[1]
        }
        
        guard let contentURLString = contents[URLKey],
            let contentsURL = URL(string: contentURLString) else {
            return nil
        }
        
        let contentTitle = contents[titleKey]
        
        var contentImageType: URLMediaObject.URLFileContents.ImageType?
        if let contentImageTypeString = contents[imageTypeKey] {
            contentImageType = URLMediaObject.URLFileContents.ImageType(rawValue: contentImageTypeString)
        }
        
        return URLFileContents(url: contentsURL, title: contentTitle, imageType: contentImageType)
    }
    
    static func loadMediaForActivityViewController(uuids: [String]) -> [Any] {
        var urlMedia = [Any]()
        
        for uuid in uuids {
            if let urlObj = URLMediaObject.fetchObjectWithUUID(uuid) {
                if !urlObj.readProblem, let url = urlObj.url {
                    if let contents = parseURLFile(localURLFile: url as URL) {
                        urlMedia += [contents.url]
                    }
                }
                urlMedia.append(urlObj)
            }
        }
        
        return urlMedia
    }
}
