//
//  ImageCache.swift
//  SharedImages
//
//  Created by Christopher Prince on 6/22/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SMCoreLib

protocol CacheDataSource {
    associatedtype CachedData
    associatedtype CachedDataArg
    
    // The args must define a unique key, which will be associated with the cached data.
    func keyFor(args:CachedDataArg) -> String
    
    // Return the cached data from the data source given the args.
    func cacheDataFor(args:CachedDataArg) -> CachedData
    
    // If you have given a maxCost in the init method of `LRUCache`, then this method must return non-nil. This method is expected to return the same value each time for the same CachedData.
    func costFor(_ item: CachedData) -> Int?
    
#if DEBUG
    // Item was freshly cached on call to `get`
    func cachedItem(_ item:CachedData)
    
    // An item had to be evicted when `get` was called.
    func evictedItemFromCache(_ item:CachedData)
#endif
}

// Had some problems figuring out this generic technique: https://stackoverflow.com/questions/44714627/in-swift-how-do-i-use-an-associatedtype-in-a-generic-class-where-the-type-param#44714782
class LRUCache<DataSource:CacheDataSource> {
    typealias CacheData = DataSource.CachedData
    typealias Arg = DataSource.CachedDataArg
    private var lruKeys = NSMutableOrderedSet()
    private var contents = [String: CacheData]()
    private var currentCost:UInt64 = 0
    let maxItems:UInt!
    let maxCost:UInt64?
    
    // Items are evicted from the cache when the max number of items is exceeded, or if the maxCost is given and the maxCost is exceeded. At least one item will be stored in the cache, even if it exceeds the max cost.
    init?(maxItems:UInt, maxCost:UInt64? = nil) {
        guard maxItems > 0 else {
            return nil
        }
        
        guard maxCost == nil || maxCost! > 0 else {
            return nil
        }

        self.maxItems = maxItems
        self.maxCost = maxCost
    }
    
    // If data is cached, returns it. If data is not cached obtains, caches, and returns it.
    func getItem(from dataSource:DataSource, with args:Arg) -> CacheData {
        let key = dataSource.keyFor(args: args)
        
        if let cachedData = contents[key] {
            // Remove key from lruKeys and put it at start-- gotta keep that LRU property.
            lruKeys.remove(key)
            lruKeys.insert(key, at: 0)
            return cachedData
        }
        
        func evictItem(withKey key: String) {
            let item = contents[key]!
#if DEBUG
            dataSource.evictedItemFromCache(item)
#endif

            if maxCost != nil {
                print("currentCost, before eviction: \(currentCost)")
                currentCost -= UInt64(dataSource.costFor(item)!)
            }
            
            lruKeys.remove(key)
            contents[key] = nil
        }
        
        // Check if we've exceed item limit in the cache.
        if lruKeys.count == Int(maxItems) {
            // Evict LRU key and data
            let lruKey = lruKeys.object(at: lruKeys.count-1) as! String
            evictItem(withKey: lruKey)
        }
        
        let newItemForCache = dataSource.cacheDataFor(args: args)
        
        // We may have to evict item(s) due to extra cost.
        if maxCost != nil {
            let extraCost = dataSource.costFor(newItemForCache)!
            
            // Need to bring the cost of the current items down, in an LRU manner.
            while (UInt64(extraCost) + UInt64(currentCost) > maxCost!) && lruKeys.count > 0 {
                let lruKey = lruKeys.object(at: lruKeys.count-1) as! String
                evictItem(withKey: lruKey)
            }
            
            currentCost += UInt64(extraCost)
        }
        
        // Add new data in.
        lruKeys.insert(key, at: 0)
        contents[key] = newItemForCache
        
#if DEBUG
        dataSource.cachedItem(newItemForCache)
#endif

        return newItemForCache
    }
}
