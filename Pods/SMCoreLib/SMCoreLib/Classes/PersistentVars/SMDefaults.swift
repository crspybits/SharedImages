//
//  SMDefaults.swift
//  Catsy
//
//  Created by Christopher Prince on 7/12/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

// A wrapper over NSUserDefaults to make it easier to use.

import Foundation

// Need NSObject inheritance for NSCoding.
open class SMDefaultItem : NSObject {
    let name:String!
    let initialValue:AnyObject!
    
    init(name:String!, initialValue:AnyObject!) {
        self.name = name
        self.initialValue = initialValue
        SMDefaults.session().names.insert(name)
    }
    
    // Reset just this NSUserDefault value.
    func reset() {
        SMDefaults.session().reset(self.name)
    }
}

class SMDefaultItemBool : SMDefaultItem {
    init(name:String!, initialBoolValue:Bool!) {
        super.init(name: name, initialValue:initialBoolValue as AnyObject!)
    }
    
    // Current Bool value
    var boolValue:Bool {
        get {
            let defsStoredValue: AnyObject? = UserDefaults.standard.object(forKey: self.name) as AnyObject?
            if (nil == defsStoredValue) {
                // No value in NSUserDefaults; return the initial value.
                return self.initialValue!.boolValue
            }
            else {
                return defsStoredValue!.boolValue
            }
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: self.name)
            SMDefaults.session().save()
        }
    }
}

open class SMDefaultItemInt : SMDefaultItem {
    init(name:String!, initialIntValue:Int!) {
        super.init(name: name, initialValue:initialIntValue as AnyObject!)
    }
    
    // Current Int value
    var intValue:Int {
        get {
            let defsStoredValue: AnyObject? = UserDefaults.standard.object(forKey: self.name) as AnyObject?
            if (nil == defsStoredValue) {
                // No value in NSUserDefaults; return the initial value.
                return self.initialValue!.intValue
            }
            else {
                return defsStoredValue!.intValue
            }
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: self.name)
            SMDefaults.session().save()
        }
    }
    
    var intDefault:Int {
        return self.initialValue as! Int
    }
}

class SMDefaultItemArchivable : SMDefaultItem {
    override init(name:String!, initialValue:AnyObject!) {
        super.init(name: name, initialValue:initialValue)
    }
    
    // Current value
    var value:AnyObject? {
        get {
            let defsStoredData = UserDefaults.standard.object(forKey: self.name) as? Data
            if (nil == defsStoredData) {
                // No value in NSUserDefaults; return the initial value.
                return self.initialValue
            }
            else {
                let unarchivedValue: AnyObject? = NSKeyedUnarchiver.unarchiveObject(with: defsStoredData!) as AnyObject?
                return unarchivedValue
            }
        }
        
        set {
            self.save(newValue)
        }
    }
    
    fileprivate func save(_ value:AnyObject!) {
        let archivedData = NSKeyedArchiver.archivedData(withRootObject: value)
        UserDefaults.standard.set(archivedData, forKey: self.name)
        SMDefaults.session().save()
    }
}

// I wanted the SMDefaultItemSet class to be a generic class using Swift sets. But, generics in swift don't play well with NSCoding, so I'm just going to use NSMutableSet instead :(.
class SMDefaultItemSet : SMDefaultItemArchivable {
    //private var myContext = 0 // Apple says this is needed for KVO
    
    // The sets you give here should have elements abiding by NSCoding. 
    init(name:String!, initialSetValue:NSMutableSet!) {
        super.init(name: name, initialValue:initialSetValue)
        
        // Note we're not observing the setValue property directly. See below.
        // Actually, it turns out we don't need this observer *at all* when using the proxy methods below.
        //self.addObserver(self, forKeyPath: "setValueWrapper", options: nil, context: &myContext)
    }
    
    deinit {
        //self.removeObserver(self, forKeyPath: "setValueWrapper", context: &myContext)
    }
    
    // Note that each time this is called/used, it retrieves the value from NSUserDefaults
    fileprivate var theSetValue:NSMutableSet {
        return self.value as! NSMutableSet
    }
    
    // In order to get a KVO style of access working for mutations to the NSMutableSet (i.e., updates to it, not just changes to the property), I have to use proxy methods.
    // See https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/KeyValueCoding/Articles/AccessorConventions.html
    // and https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/KeyValueCoding/Articles/SearchImplementation.html
    // http://www.objc.io/issues/7-foundation/key-value-coding-and-observing/
    // The problem here revolves around my use of a setValue getter. This would, more typically, return an NSMutableSet. HOWEVER, then, when the caller adds/removes items to/from the set, the changed set is *not* saved to NSUserDefaults. All of this stuff with proxy methods amounts to getting callbacks when the caller changes the set (and now, proxy, set) returned by the setValue getter.
    
    //MARK: Start proxy methods
    
    // Note that these methods *cannot* be private!!! If they are, the runtime system doesn't find them.
    func countOfSetValueWrapper() -> UInt {
        return UInt(theSetValue.count)
    }
    
    func enumeratorOfSetValueWrapper() -> NSEnumerator {
        return theSetValue.objectEnumerator()
    }
    
    func memberOfSetValueWrapper(_ object:AnyObject!) -> AnyObject? {
        return theSetValue.member(object) as AnyObject?
    }
    
    // For the following two accessors, use the add<Key>Object methods as these are for individual objects; otherwise, the parameter is actually passed as a set.
    func addSetValueWrapperObject(_ object:AnyObject!) {
        let set = theSetValue
        set.add(object)
        self.save(set)
    }
    
    func removeSetValueWrapperObject(_ object:AnyObject!) {
        let set = theSetValue
        set.remove(object)
        self.save(set)
    }
    
    //MARK: End proxy methods

    // It looks like in order to get this called, we needed to implement the above proxy methods. However, now with those proxy methods, I don't need this observer any more.
    /*
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
    }*/
    
    var setValue:NSMutableSet! {
        get {
            // Return the proxy object. The proxy methods are named as, for example, add<Key>Object where key is SetValueWrapper, which is the key below, but with the first letter capitalized.
            return self.mutableSetValue(forKey: "setValueWrapper")
        }
        
        set {
            super.value = newValue
        }
    }
}

@objc class SMDefaults : NSObject {
    // Singleton class.
    fileprivate static let theSession = SMDefaults()
    
    // I have this as a class function and not a public static property to enable access from Objective-C
    class func session() -> SMDefaults {
        return self.theSession
    }
    
    // The names of all the defaults. Just held in RAM (not stored in NSUserDefaults itself) so we can do a reset of all of the items stored in NSUserDefaults if needed.
    fileprivate var names = Set<String>()
    
    fileprivate override init() {
        super.init()
    }
    
    // Reset all the defaults.
    func reset() {
        for name in names {
            self.reset(name)
        }
        self.save()
    }
    
    func reset(_ name:String) {
        UserDefaults.standard.removeObject(forKey: name)
        self.save()
    }
    
    fileprivate func save() {
        UserDefaults.standard.synchronize()
    }
}

class SMDefaultsTest {
#if DEBUG
    static let TEST_BOOL = SMDefaultItemBool(name: "TestBool", initialBoolValue:true)
    static let TEST_INT = SMDefaultItemInt(name: "TestInt", initialIntValue:0)
    static let TEST_SET = SMDefaultItemSet(name: "TestSet", initialSetValue:NSMutableSet())
    
    private enum TestType {
        case JustPrint
        case ChangeValues
        case Reset
    }
    
    class func run() {
        print("before: self.TEST_BOOL.boolValue: \(self.TEST_BOOL.boolValue)", terminator: "")
        print("before: self.TEST_INT.intValue: \(self.TEST_INT.intValue)", terminator: "")
        print("before: self.TEST_SET.setValue: \(self.TEST_SET.setValue)", terminator: "")

        let testType:TestType = .ChangeValues
        
        switch (testType) {
        case .JustPrint:
            break // nop
            
        case .ChangeValues:
            self.TEST_BOOL.boolValue = false
            self.TEST_INT.intValue += 1
            self.TEST_SET.setValue.add(NSDate())
            
        case .Reset:
            SMDefaults.session().reset()
        }
        
        print("after: self.TEST_BOOL.boolValue: \(self.TEST_BOOL.boolValue)", terminator: "")
        print("before: self.TEST_INT.intValue: \(self.TEST_INT.intValue)", terminator: "")
        print("after: self.TEST_SET.setValue: \(self.TEST_SET.setValue)", terminator: "")
    }
    
#endif
}
