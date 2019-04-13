//
//  CacheTests.swift
//  SharedImagesTests
//
//  Created by Christopher Prince on 6/22/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import XCTest
@testable import Neebla

class CacheTests: XCTestCase {
    var numberEvicted = 0
    var numberCached = 0
    var itemCached:Any?
    var evictedItem:Any?
    var itemCosts:[Int:Int]!
    
    override func setUp() {
        super.setUp()
        numberEvicted = 0
        numberCached = 0
        itemCached = nil
        evictedItem = nil
        itemCosts = [Int:Int]()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCacheCreationFailure() {
        let cache = LRUCache<CacheTests>(maxItems: 0)
        XCTAssert(cache == nil)
    }
    
    func testCacheFirstGet() {
        let cache = LRUCache<CacheTests>(maxItems: 1)
        XCTAssert(cache != nil)
        
        let valueToCache:Int = 132
        let result = cache?.getItem(from: self, with: valueToCache)
        XCTAssert(result == valueToCache)
        
        XCTAssert(numberCached == 1)
        XCTAssert(numberEvicted == 0)
    }
    
    func testCacheRepeatedGet() {
        let cache = LRUCache<CacheTests>(maxItems: 1)
        XCTAssert(cache != nil)
        
        let valueToCache:Int = 132
        var result = cache?.getItem(from: self, with: valueToCache)
        XCTAssert(result == valueToCache)
        XCTAssert(numberCached == 1)
        XCTAssert(numberEvicted == 0)
        numberCached = 0
        
        result = cache?.getItem(from: self, with: valueToCache)
        XCTAssert(result == valueToCache)
        XCTAssert(numberCached == 0)
        XCTAssert(numberEvicted == 0)
    }
    
    func testCacheFirstEviction() {
        let cache = LRUCache<CacheTests>(maxItems: 1)
        XCTAssert(cache != nil)
        
        let firstValue:Int = 132
        var result = cache?.getItem(from: self, with: firstValue)
        XCTAssert(result == firstValue)
        XCTAssert(numberCached == 1)
        XCTAssert(numberEvicted == 0)
        numberCached = 0
        
        let secondValue = 676
        result = cache?.getItem(from: self, with: secondValue)
        XCTAssert(result == secondValue)
        XCTAssert(numberCached == 1)
        XCTAssert(numberEvicted == 1)
        numberCached = 0
        XCTAssert(evictedItem as! Int == firstValue)
    }
    
    func testCacheSecondGetNoEviction() {
        let cache = LRUCache<CacheTests>(maxItems: 2)
        XCTAssert(cache != nil)
        
        let firstValue:Int = 132
        var result = cache?.getItem(from: self, with: firstValue)
        XCTAssert(result == firstValue)
        XCTAssert(numberCached == 1)
        XCTAssert(numberEvicted == 0)
        numberCached = 0
        
        let secondValue = 676
        result = cache?.getItem(from: self, with: secondValue)
        XCTAssert(result == secondValue)
        XCTAssert(numberCached == 1)
        XCTAssert(numberEvicted == 0)
        numberCached = 0
    }

    func testCacheLRUPolicy() {
        let cache = LRUCache<CacheTests>(maxItems: 2)
        XCTAssert(cache != nil)
        
        let firstValue:Int = 132
        var result = cache?.getItem(from: self, with: firstValue)
        XCTAssert(result == firstValue)
        XCTAssert(numberCached == 1)
        XCTAssert(numberEvicted == 0)
        numberCached = 0
        
        let secondValue = 676
        result = cache?.getItem(from: self, with: secondValue)
        XCTAssert(result == secondValue)
        XCTAssert(numberCached == 1)
        XCTAssert(numberEvicted == 0)
        numberCached = 0
        
        let thirdValue = 22
        result = cache?.getItem(from: self, with: thirdValue)
        XCTAssert(result == thirdValue)
        XCTAssert(numberCached == 1)
        XCTAssert(numberEvicted == 1)
        XCTAssert(evictedItem as! Int == firstValue)
    }
    
    func testCacheLRUPolicyWithRecentGet() {
        let cache = LRUCache<CacheTests>(maxItems: 2)
        XCTAssert(cache != nil)
        
        let firstValue:Int = 132
        var result = cache?.getItem(from: self, with: firstValue)
        XCTAssert(result == firstValue)
        XCTAssert(numberCached == 1)
        XCTAssert(numberEvicted == 0)
        numberCached = 0
        
        let secondValue = 676
        result = cache?.getItem(from: self, with: secondValue)
        XCTAssert(result == secondValue)
        XCTAssert(numberCached == 1)
        XCTAssert(numberEvicted == 0)
        numberCached = 0
        
        result = cache?.getItem(from: self, with: firstValue)
        
        let thirdValue = 22
        result = cache?.getItem(from: self, with: thirdValue)
        XCTAssert(result == thirdValue)
        XCTAssert(numberCached == 1)
        XCTAssert(numberEvicted == 1)
        XCTAssert(evictedItem as! Int == secondValue)
    }
    
    // MARK: Test when having a max cost
    
    func testWithBadCost() {
        let cache = LRUCache<CacheTests>(maxItems: 1, maxCost:0)
        XCTAssert(cache == nil)
    }
    
    func testCacheWithCostRepeatedGet() {
        let cache = LRUCache<CacheTests>(maxItems: 1, maxCost:10)
        XCTAssert(cache != nil)
        
        let valueToCache:Int = 132
        itemCosts[valueToCache] = 1
        var result = cache?.getItem(from: self, with: valueToCache)
        XCTAssert(result == valueToCache)
        XCTAssert(numberCached == 1)
        XCTAssert(numberEvicted == 0)
        numberCached = 0
        
        result = cache?.getItem(from: self, with: valueToCache)
        XCTAssert(result == valueToCache)
        XCTAssert(numberCached == 0)
        XCTAssert(numberEvicted == 0)
    }
    
    func testThatCacheCanStoreOneItemThatDoesNotExceedMaxCost() {
        let cache = LRUCache<CacheTests>(maxItems: 1, maxCost:1)
        XCTAssert(cache != nil)
        
        let valueToCache:Int = 132
        itemCosts[valueToCache] = 1
        let result = cache?.getItem(from: self, with: valueToCache)
        XCTAssert(result == valueToCache)
        
        XCTAssert(numberCached == 1)
        XCTAssert(numberEvicted == 0)
    }

    func testThatCacheCanStoreOneItemThatExceedsMaxCost() {
        let cache = LRUCache<CacheTests>(maxItems: 1, maxCost:1)
        XCTAssert(cache != nil)
        
        let valueToCache:Int = 132
        itemCosts[valueToCache] = 100
        let result = cache?.getItem(from: self, with: valueToCache)
        XCTAssert(result == valueToCache)
        
        XCTAssert(numberCached == 1)
        XCTAssert(numberEvicted == 0)
    }

    func testThatCacheEvictsItemWhenMaxCostExceeded() {
        let cache = LRUCache<CacheTests>(maxItems: 2, maxCost:10)
        XCTAssert(cache != nil)
        
        let firstValue:Int = 132
        itemCosts[firstValue] = 5
        
        var result = cache?.getItem(from: self, with: firstValue)
        XCTAssert(result == firstValue)
        XCTAssert(numberCached == 1)
        XCTAssert(numberEvicted == 0)
        numberCached = 0
        
        let secondValue:Int = 60
        itemCosts[secondValue] = 6
        result = cache?.getItem(from: self, with: secondValue)
        XCTAssert(result == secondValue)
        XCTAssert(numberCached == 1, "numberCached was \(numberCached)")
        XCTAssert(numberEvicted == 1)
        XCTAssert(evictedItem as! Int == firstValue)
    }
    
    func testThatCacheCanEvictMoreThanOneItemToBringCostDown() {
        let cache = LRUCache<CacheTests>(maxItems: 10, maxCost:10)
        XCTAssert(cache != nil)
        
        let firstValue:Int = 132
        itemCosts[firstValue] = 2
        
        var result = cache?.getItem(from: self, with: firstValue)
        XCTAssert(result == firstValue)
        XCTAssert(numberCached == 1)
        XCTAssert(numberEvicted == 0)
        numberCached = 0
        
        let secondValue:Int = 60
        itemCosts[secondValue] = 2
        result = cache?.getItem(from: self, with: secondValue)
        XCTAssert(result == secondValue)
        XCTAssert(numberCached == 1, "numberCached was \(numberCached)")
        XCTAssert(numberEvicted == 0)
        numberCached = 0

        let thirdValue:Int = 33
        itemCosts[thirdValue] = 10
        result = cache?.getItem(from: self, with: thirdValue)
        XCTAssert(result == thirdValue)
        XCTAssert(numberCached == 1, "numberCached was \(numberCached)")
        XCTAssert(numberEvicted == 2)
    }
}

extension CacheTests : CacheDataSource {

    func keyFor(args:Int) -> String {
        return "\(args)"
    }
    func cacheDataFor(args:Int) -> Int {
        return args
    }
    
    func costFor(_ item: Int) -> Int? {
        return itemCosts[item]
    }
    
    func cachedItem(_ item:Int) {
        itemCached = item
        numberCached += 1
    }
    
    func evictedItemFromCache(_ item:Int) {
        evictedItem = item
        numberEvicted += 1
    }
}
