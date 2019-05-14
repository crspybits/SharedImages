//
//  LinkSource.swift
//  SMLinkPreview
//
//  Created by Christopher G Prince on 4/20/19.
//

import Foundation

public struct LinkData {    
    public let url: URL
    public let title: String?
    public let description: String?
    public let image: URL?
    public let icon: URL?
    
    public init(url: URL, title: String?, description: String?, image: URL?, icon: URL?) {
        self.url = url
        self.image = image
        self.icon = icon
        self.description = description
        self.title = title
    }
}

public struct APIKey {
    public let requestKey: String
    public let value: String
    
    public init(requestKey: String, value: String) {
        self.requestKey = requestKey
        self.value = value
    }
    
    // Don't give the .plist extension with the plistName
    public static func getFromPlist(plistKeyName: String, requestKeyName: String, plistName: String, bundle: Bundle = Bundle.main) -> APIKey? {
        
        if let path = bundle.path(forResource: plistName, ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path),
            let value = dict[plistKeyName] as? String {
            return APIKey(requestKey: requestKeyName, value: value)
        }
        
        return nil
    }
}

public protocol LinkSource {
    static var requestKeyName: String? {get}
    init?(apiKey: APIKey?)
    func getLinkData(url: URL, completion: @escaping (LinkData?)->())
}

