//
//  PreviewManager.swift
//  SMLinkPreview
//
//  Created by Christopher G Prince on 4/20/19.
//

import Foundation

public struct PreviewConfiguration {
    public let alwaysUseHTTPS: Bool // Use https for all remote image loading? Default is true because otherwise app needs ATS set to allow insecure loading. This is not relevant for local image loading.
    public let maxNumberTitleLines: UInt // 0 means unlimited
    
    public init(alwaysUseHTTPS: Bool = true, maxNumberTitleLines: UInt = 0) {
        self.alwaysUseHTTPS = alwaysUseHTTPS
        self.maxNumberTitleLines = maxNumberTitleLines
    }
}

public class PreviewManager {
    private init() {}
    private var sources = [LinkSource]()

    public static let session = PreviewManager()
    public var config = PreviewConfiguration()
    
    // Use this to apply a filtering constraint on the LinkData returned by the API souurce. e.g., require that an image or an icon is present.
    public var linkDataFilter: ((LinkData)->(Bool))?
    
    // Add LinkSource's in the order you want them tried.
    public func add(source: LinkSource) {
        sources += [source]
    }
    
    // For testing
    func reset() {
        sources = []
    }
    
    public func getLinkData(url: URL, completion: @escaping (LinkData?)->()) {
        getLinkDataAux(sources: sources, url: url, completion: completion)
    }
    
    func onMainThread(completion: @escaping ()->()) {
        if Thread.isMainThread {
            completion()
        }
        else {
            DispatchQueue.main.sync {
                completion()
            }
        }
    }
    
    func getLinkDataAux(sources: [LinkSource], url: URL, completion: @escaping (LinkData?)->()) {
        if sources.count == 0 {
            onMainThread {completion(nil)}
        }
        else {
            let source = sources[0]
            let tail = sources.count > 1 ? Array(sources[1...sources.count-1]) : [LinkSource]()
            source.getLinkData(url: url) {[unowned self] linkData in
                guard let linkData = linkData else {
                    // With a failure, try next as failover method(s).
                    self.getLinkDataAux(sources: tail, url: url, completion: completion)
                    return
                }
                
                guard let filter = self.linkDataFilter else {
                    // This is not a failure: There's just no filter. Return what we found!
                    self.onMainThread {completion(linkData)}
                    return
                }
                
                if filter(linkData) {
                    self.onMainThread {completion(linkData)}
                }
                else {
                    // linkData didn't meet the filter constraint-- try next.
                    self.getLinkDataAux(sources: tail, url: url, completion: completion)
                }
            }
        }
    }
}
