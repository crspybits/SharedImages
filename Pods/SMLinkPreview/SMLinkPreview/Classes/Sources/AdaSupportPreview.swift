//
//  AdaSupportPreview.swift
//  SMLinkPreview
//
//  Created by Christopher G Prince on 4/20/19.
//

import Foundation

// See https://github.com/AdaSupport/preview

public class AdaSupportPreview: LinkSource {
    public static var requestKeyName: String?
    // Parameter must have scheme stripped off. E.g., slack.com
    let route = "https://previews.ada.support/?url="
    
    required public init?(apiKey: APIKey?) {
    }
    
    public func getLinkData(url: URL, completion: @escaping (LinkData?) -> ()) {
        guard let urlWithoutScheme = url.urlWithoutScheme() else {
            completion(nil)
            return
        }
        
        let routeString = route + urlWithoutScheme        
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
            
            guard let dict = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0)) as? [String: Any] else {
                completion(nil)
                return
            }
            
            guard let description = dict["desc"] as? String else {
                completion(nil)
                return
            }
            
            guard let name = dict["title"] as? String else {
                completion(nil)
                return
            }
            
            var imageURL: URL?
            var iconURL: URL?
            
            // *Some* resulting image URLs have the form: https://ada-previewer.imgix.net/https%3A%2F%2Fgithub.githubassets.com%2Fimages%2Fmodules%2Fopen_graph%2Fgithub-logo.png?ixlib=python-2.0.0&max-w=768&s=8c8f8b48c8f633734d360f49f7b3ef29
            
            if let previewerURLString = dict["image"] as? String,
                let previewerURL = URL(string: previewerURLString) {
                let imageURLString = previewerURL.path
                if imageURLString.count > 1 {
                    let imageURLStringWithoutFirst = String(imageURLString.dropFirst())
                    
                    if imageURLStringWithoutFirst.hasPrefix("http") {
                        imageURL = URL(string: imageURLStringWithoutFirst)
                    }
                }
            }
            
            // And some image URL's are just plain URL's referencing images...
            if imageURL == nil, let urlString = dict["image"] as? String {
                imageURL = URL(string: urlString)
            }

            if let icon = dict["icon"] as? String {
                iconURL = URL(string: icon)
            }
            
            let linkData = LinkData(url: url, title: name, description: description, image: imageURL, icon: iconURL)
            completion(linkData)
        }
        
        dataTask.resume()
    }
}
