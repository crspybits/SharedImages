//
//  MicrolinkPreview.swift
//  SMLinkPreview
//
//  Created by Christopher G Prince on 4/20/19.
//

import Foundation

// See https://www.indiehackers.com/forum/show-ih-microlink-io-beautiful-links-previews-for-any-website-8fee2613af

public class MicrolinkPreview: LinkSource {
    public static var requestKeyName: String?
    let route = "https://api.microlink.io/?url="
    
    required public init?(apiKey: APIKey?) {
    }
    
    public func getLinkData(url: URL, completion: @escaping (LinkData?) -> ()) {
        let routeString = route + url.absoluteString
        guard let routeURL = URL(string: routeString) else {
            completion(nil)
            return
        }
        
        let request = URLRequest(url: routeURL)
        let dataTask = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            guard let dataDict = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0)) as? [String: Any] else {
                completion(nil)
                return
            }
            
            guard let dict = dataDict["data"] as? [String: Any] else {
                completion(nil)
                return
            }
            
            /*
            {"data":{"lang":"en","author":"Catch Themes","title":"Home sweet home","publisher":null,"image":{"url":"http://cprince.com/WordPress/wp-content/uploads/2013/10/tree-225x300.jpg","width":225,"height":300,"type":"jpg","size":40254,"size_pretty":"40.3 kB"},"description":"Welcome to my web page. Web pages are funny (they make me laugh). A store front for a person. An Internet presence. Information about yourself that every-internet-navigating person on the planet above age two can access. Is it the truth? Perhaps it’s Google-true?","date":null,"logo":{"url":"http://cprince.com/WordPress/wp-content/uploads/2013/11/IMG_09254.jpg","width":133,"height":100,"type":"jpg","size":6476,"size_pretty":"6.48 kB"},"url":"http://cprince.com"},"status":"success"}
            */
            
            let description = dict["description"] as? String
            let name = dict["title"] as? String
            
            var imageURL: URL?
            var iconURL: URL?
            
            if let logoDict = dict["logo"] as? [String: Any],
                let logo = logoDict["url"] as? String {
                iconURL = URL(string: logo)
            }

            if let imageDict = dict["image"] as? [String: Any],
                let image = imageDict["url"] as? String {
                imageURL = URL(string: image)
            }
            
            let linkData = LinkData(url: url, title: name, description: description, image: imageURL, icon: iconURL)
            completion(linkData)
        }
        
        dataTask.resume()
    }
}
