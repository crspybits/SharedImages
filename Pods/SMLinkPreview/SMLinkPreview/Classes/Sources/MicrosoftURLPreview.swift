//
//  MicrosoftURLPreview.swift
//  SMLinkPreview
//
//  Created by Christopher G Prince on 4/20/19.
//

import Foundation

// See https://labs.cognitive.microsoft.com/en-us/project-url-preview

public class MicrosoftURLPreview: LinkSource {
    public static var requestKeyName: String? = "Ocp-Apim-Subscription-Key"
    let apiKey: APIKey
    let route = "https://api.labs.cognitive.microsoft.com/urlpreview/v7.0/search?q="
    
    required public init?(apiKey: APIKey?) {
        guard let apiKey = apiKey else {
            return nil
        }
        
        self.apiKey = apiKey
    }
    
    public func getLinkData(url: URL, completion: @escaping (LinkData?) -> ()) {
        let routeString = route + url.absoluteString
        
        guard let routeURL = URL(string: routeString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: routeURL)
        request.addValue(apiKey.value, forHTTPHeaderField: apiKey.requestKey)
        
        let dataTask = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            guard let dict = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0)) as? [String: Any] else {
                completion(nil)
                return
            }
            
            guard let description = dict["description"] as? String else {
                completion(nil)
                return
            }
            
            guard let name = dict["name"] as? String else {
                completion(nil)
                return
            }
            
            var imageURL: URL?
            
            if let imageDict = dict["primaryImageOfPage"] as? [String: Any],
                let image = imageDict["contentUrl"] as? String {
                imageURL = URL(string: image)
            }
            
            let linkData = LinkData(url: url, title: name, description: description, image: imageURL, icon: nil)
            completion(linkData)
        }
        
        dataTask.resume()
    }
}
