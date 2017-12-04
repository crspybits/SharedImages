//
//  SMPersistVars.swift
//  Catsy
//
//  Created by Christopher Prince on 7/12/15.
//  Copyright (c) 2015 Spastic Muffin, LLC. All rights reserved.
//

// A generalization over NSUserDefaults, and KeyChain (and later, perhaps iCloud) to deal with  variables that persist across launches of an app.

import Foundation

// The different persistent variable types have separate name spaces. I.e., you can use the same name (see init method below) in across user defaults and keychain.
public enum SMPersistVarType {
    case userDefaults
    case keyChain
}

private let KEYCHAIN_ACCOUNT = "SMPersistVars"

// Need NSObject inheritance for NSCoding.
open class SMPersistItem : NSObject {
    // if you set isMutable to true in your subclass, it is important that you implement .mutableCopy if your SMPersistItem subclass has a non-primitive/non-built-in mutable class. E.g., my SMPersistItemDict class uses SMMutableDictionary internally (not NSMutableDictionary). cachedOrArchivedValue makes a .mutableCopy and, if we didn't implement our own mutableCopy method, we'd get an NSMutableDictionary as a result which causes a crash.
    fileprivate var isMutable:Bool = false
    
    // Some subclasses have specific archive/unarchive methods.
    fileprivate var unarchiveValueMethod:((_ data:Data?) -> (AnyObject?))?
    fileprivate var archiveValueMethod:((_ value:AnyObject?) -> (Data?))?
    
    fileprivate  let initialValue:AnyObject!
    
    // 10/31/15; I've introduced this for performance reasons, and specifically for the KeyChain persistence type, but will use it for NS user defaults too just for generality.
    fileprivate var _cachedCurrentValue:AnyObject?
    
    open let persistType:SMPersistVarType
    open let name:String

    init(name:String!, initialValue:AnyObject!, persistType:SMPersistVarType) {
        self.name = name
        self.initialValue = initialValue
        self.persistType = persistType
        
        Log.msg("type: \(self.persistType); name: \(self.name); initialValue: \(self.initialValue); initialValueType: \(type(of: initialValue))")
        
        switch (persistType) {
        case .userDefaults:
            SMPersistVars.session().userDefaultNames.insert(name)
            
        case .keyChain:
            SMPersistVars.session().keyChainNames.insert(name)
        }
    }
    
    // Reset just this value.
    open func reset() {
        switch (self.persistType) {
        case .userDefaults:
            SMPersistVars.session().resetUserDefaults(self.name)
            
        case .keyChain:
            SMPersistVars.session().resetKeyChain(self.name)
        }
        
        self._cachedCurrentValue = nil
    }
    
    fileprivate func unarchiveValue(_ data:Data!) -> AnyObject? {
        var unarchivedValue: AnyObject?
        
        if nil == self.unarchiveValueMethod {
            unarchivedValue = NSKeyedUnarchiver.unarchiveObject(with: data) as AnyObject?
        }
        else {
            unarchivedValue = self.unarchiveValueMethod!(data)
        }
        
        return unarchivedValue
    }
    
    fileprivate func archiveValue(_ value:AnyObject!) -> Data? {
        var archivedData:Data?
        
        if nil == self.archiveValueMethod {
            archivedData = NSKeyedArchiver.archivedData(withRootObject: value)
        }
        else {
            archivedData = self.archiveValueMethod!(value)
        }
        
        return archivedData
    }
    
    // [1]. 11/14/15; I changed the return value from NSData? to AnyObject? because v1.2 of Catsy had Int's and Bool's stored in NSUserDefaults for SMDefaultItemInt's and SMDefaultItemBool's. i.e., objectForKey would directly return an Int or Bool (as an NSNumber, I believe).
    fileprivate func getPersistentValue() -> AnyObject? {
        var defsStoredValue:AnyObject?

        switch (self.persistType) {
        case .userDefaults:
            defsStoredValue = UserDefaults.standard.object(forKey: self.name) as AnyObject?
            
        case .keyChain:
            defsStoredValue = KeyChain.secureData(forService: self.name, account: KEYCHAIN_ACCOUNT) as AnyObject?
        }
        
        return defsStoredValue
    }
    
    fileprivate func savePersistentValue(_ value:AnyObject!) -> Bool {
        let archivedData = self.archiveValue(value)
        if nil == archivedData {
            Log.error("savePersistentValue: Failed")
            return false
        } else {
            self.savePersistentData(archivedData!)
            return true
        }
    }
    
    fileprivate func savePersistentData(_ data:Data!) {
        switch (self.persistType) {
        case .userDefaults:
            UserDefaults.standard.set(data, forKey: self.name)
            SMPersistVars.session().saveUserDefaults()
            
        case .keyChain:
            KeyChain.setSecureData(data, forService: self.name, account: KEYCHAIN_ACCOUNT)
        }
    }
    
    fileprivate var cachedOrArchivedValue:AnyObject? {
        get {
            if self._cachedCurrentValue != nil {
                return self._cachedCurrentValue
            }
            
            var returnValue:AnyObject?
            let persistentValue = self.getPersistentValue()
            
            if (nil == persistentValue) {
                
                // No value; return the initial value.
                if self.isMutable {
                    // It is important to return a mutable copy here-- because the returned object may get mutated. If we don't return a mutable copy, we'll get mutating changes to self.initialValue, which we definitely do not want.
                    
                    // 12/1/16; I was having a compiler crash here.
                    // This is what was causing it:
                    // return self.initialValue.mutableCopy() as AnyObject!

                    if let initialObjValue = self.initialValue as? NSObject {
                         let result = initialObjValue.mutableCopy()
                        return result as AnyObject
                    }
                    else {
                        Assert.badMojo(alwaysPrintThisString: "Yikes: Could not make mutable copy")
                    }
                }
                else {
                    returnValue = self.initialValue
                }
            }
            else {
                if persistentValue is NSData {
                    let unarchivedValue = self.unarchiveValue(persistentValue! as! Data)
                    Log.msg("name: \(self.name); \(String(describing: unarchivedValue)); type: \(type(of: unarchivedValue))")
                    returnValue = unarchivedValue
                }
                else {
                    // Should be an Int or Bool; see [1] above.
                    Assert.If(!(persistentValue is Bool) && !(persistentValue is Int), thenPrintThisString: "Yikes: don't have an Int or a Bool or NSData!")
                    returnValue = persistentValue
                }
            }
            
            self._cachedCurrentValue = returnValue
            return returnValue
        }
        
        set {
            let _ = self.savePersistentValue(newValue)
            let _ = self._cachedCurrentValue = newValue
        }
    }
    
    open func print() {
        Log.msg("\(String(describing: self.cachedOrArchivedValue))")
    }
}

open class SMPersistItemBool : SMPersistItem {
    public init(name:String!, initialBoolValue:Bool!,  persistType:SMPersistVarType) {
        super.init(name: name, initialValue:initialBoolValue as AnyObject!, persistType:persistType)
    }
    
    // Current Bool value
    open var boolValue:Bool {
        get {
            return self.cachedOrArchivedValue as! Bool
        }
        
        set {
            self.cachedOrArchivedValue = newValue as AnyObject?
        }
    }
    
    open var boolDefault:Bool {
        return self.initialValue as! Bool
    }
}

open class SMPersistItemInt : SMPersistItem {
    public init(name:String!, initialIntValue:Int!,  persistType:SMPersistVarType) {
        super.init(name: name, initialValue:initialIntValue as AnyObject!, persistType:persistType)
    }

    // Current Int value
    open var intValue:Int {
        get {
            return self.cachedOrArchivedValue as! Int
        }
        
        set {
            self.cachedOrArchivedValue = newValue as AnyObject?
        }
    }
    
    open var intDefault:Int {
        return self.initialValue as! Int
    }
}

open class SMPersistItemString : SMPersistItem {
    public init(name:String!, initialStringValue:String!,  persistType:SMPersistVarType) {
        super.init(name: name, initialValue:initialStringValue as AnyObject!, persistType:persistType)
    }
    
    // Current String value
    open var stringValue:String {
        get {
            return self.cachedOrArchivedValue as! String
        }
        
        set {
            self.cachedOrArchivedValue = newValue as AnyObject?
        }
    }
    
    open var stringDefault:String {
        return self.initialValue as! String
    }
}

open class SMPersistItemData : SMPersistItem {
    public init(name:String!, initialDataValue:Data!,  persistType:SMPersistVarType) {
        super.init(name: name, initialValue:initialDataValue as AnyObject!, persistType:persistType)
    }

    // Current NSData value
    open var dataValue:Data {
        get {
            return self.cachedOrArchivedValue as! Data
        }
        
        set {
            self.cachedOrArchivedValue = newValue as AnyObject?
        }
    }
    
    open var dataDefault:Data {
        return self.initialValue as! Data
    }
}

// I wanted the SMDefaultItemSet class to be a generic class using Swift sets. But, generics in swift don't play well with NSCoding, so I'm just going to use NSMutableSet instead :(.
// 10/6/15. POSSIBLE ISSUE: I may have an issue here. Suppose you add an object to an SMPersistItemSet which is itself mutable. E.g., an NSMutableDictionary. THEN, you change that object which is already in the mutable set. I am unsure whether or not I will detect this change and flush the change to NSUserDefaults or the KeyChain. It seems unlikely I would detect the change. NEED TO TEST.
open class SMPersistItemSet : SMPersistItem {
    //private var myContext = 0 // Apple says this is needed for KVO
    
    // The sets you give here should have elements abiding by NSCoding. 
    public init(name:String!, initialSetValue:NSMutableSet!, persistType:SMPersistVarType) {
        super.init(name: name, initialValue:initialSetValue, persistType:persistType)
        self.isMutable = true
        
        // Note we're not observing the setValue property directly. See below.
        // Actually, it turns out we don't need this observer *at all* when using the proxy methods below.
        //self.addObserver(self, forKeyPath: "setValueWrapper", options: nil, context: &myContext)
    }
    
    deinit {
        //self.removeObserver(self, forKeyPath: "setValueWrapper", context: &myContext)
    }
    
    // Note that each time this is called/used, it retrieves the value from NSUserDefaults or the KeyChain
    fileprivate var theSetValue:NSMutableSet {
        return self.cachedOrArchivedValue as! NSMutableSet
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
        let _ = self.savePersistentValue(set)
    }
    
    func removeSetValueWrapperObject(_ object:AnyObject!) {
        let set = theSetValue
        set.remove(object)
        let _ = self.savePersistentValue(set)
    }
    
    //MARK: End proxy methods

    // It looks like in order to get this called, we needed to implement the above proxy methods. However, now with those proxy methods, I don't need this observer any more.
    /*
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
    }*/
    
    open var setValue:NSMutableSet! {
        get {
            // Return the proxy object. The proxy methods are named as, for example, add<Key>Object where key is SetValueWrapper, which is the key below, but with the first letter capitalized.
            return self.mutableSetValue(forKey: "setValueWrapper")
        }
        
        set {
            self.cachedOrArchivedValue = newValue
        }
    }
    
    open var setDefault:NSMutableSet {
        // 12/1/16; This was giving a compiler crash until I fiddled with it.
        // Original code:
        // return self.initialValue.mutableCopy() as! NSMutableSet
        // See also http://stackoverflow.com/questions/24222644/swift-compiler-segmentation-fault-when-building

        let initialSetValue = self.initialValue as! NSMutableSet
        let copy = NSMutableSet(set: initialSetValue);
        return copy
    }
}

// A mutable dictionary, but being consistent with other names in this file.
open class SMPersistItemDict : SMPersistItem, SMMutableDictionaryDelegate {
    
    // The elements of your dictionaries should abide by NSCoding.
    public init(name:String!, initialDictValue:NSDictionary!, persistType:SMPersistVarType) {
        let dict = SMMutableDictionary(dictionary: initialDictValue)
        Log.msg("\(NSStringFromClass(type(of: dict)))")
        super.init(name: name, initialValue:dict, persistType:persistType)
        dict.delegate = self
        self.isMutable = true
        
        // SMMutableDictionary has specific archive/unarchive methods.
        
        self.archiveValueMethod = { (value:AnyObject?) -> Data? in
            let dict = value as! SMMutableDictionary
            let data = dict.archive()
            return data
        }
        
        self.unarchiveValueMethod = { (data:Data?) -> AnyObject? in
            if nil == data {
                return nil
            }
            let dict = SMMutableDictionary.unarchive(from: data!)
            return dict
        }
        
        Log.msg("SMPersistItemDict: name: \(self.name); type: \(self.persistType)")
    }
    
    // MARK: SMMutableDictionaryDelegate method
    
    // I don't really want this to be public but Swift says it has to be -- only for use by the delegate. Pretty please.
    open func dictionaryWasChanged(_ dictionary:SMMutableDictionary) {
        // dictionary gives the *updated* dictionary that must be saved.
        self.dictValue = dictionary
    }
    
    // MARK: End SMMutableDictionaryDelegate method
    
    open var dictValue:NSMutableDictionary! {
        get {
            let dict = self.cachedOrArchivedValue as! SMMutableDictionary
            Log.msg("\(NSStringFromClass(type(of: dict)))")
            dict.delegate = self
            return dict
        }
        
        set {
            let dict = SMMutableDictionary(dictionary: newValue)
            dict.delegate = self
            super.cachedOrArchivedValue = dict
        }
    }
    
    open var dictDefault:NSMutableDictionary {
        let dict = SMMutableDictionary(dictionary: self.initialValue as! NSMutableDictionary)
        dict.delegate = self
        return dict
    }
}

open class SMPersistItemArray : SMPersistItem {
    
    // The sets you give here should have elements abiding by NSCoding. 
    public init(name:String!, initialArrayValue:NSMutableArray!, persistType:SMPersistVarType) {
        super.init(name: name, initialValue:initialArrayValue, persistType:persistType)
        self.isMutable = true
    }
    
    // Note that each time this is called/used, it retrieves the value from NSUserDefaults or the KeyChain
    fileprivate var theArrayValue:NSMutableArray {
        return self.cachedOrArchivedValue as! NSMutableArray
    }
    
    //MARK: Start proxy methods
    
    // Note that these methods *cannot* be private!!! If they are, the runtime system doesn't find them.
    func countOfArrayValueWrapper() -> UInt {
        return UInt(theArrayValue.count)
    }
    
    func objectInArrayValueWrapperAtIndex(_ index:UInt) -> AnyObject {
        return theArrayValue.object(at: Int(index)) as AnyObject
    }
    
    // -insertObject:in<Key>AtIndex:
    func insertObject(_ object: AnyObject, inArrayValueWrapperAtIndex index:UInt) {
        let array = theArrayValue
        array.insert(object, at: Int(index))
        let _ = self.savePersistentValue(array)
    }
    
    // -removeObjectFrom<Key>AtIndex:
    func removeObjectFromArrayValueWrapperAtIndex(_ index:UInt) {
        let array = theArrayValue
        array.removeObject(at: Int(index))
        let _ = self.savePersistentValue(array)
    }
    
    //MARK: End proxy methods
    
    open var arrayValue:NSMutableArray {
        get {
            // Return the proxy object. The proxy methods are named as, for example, add<Key>Object where key is SetValueWrapper, which is the key below, but with the first letter capitalized.
            return self.mutableArrayValue(forKey: "arrayValueWrapper")
        }
        
        set {
            self.cachedOrArchivedValue = newValue
        }
    }
    
    open var arrayDefault:NSMutableArray {
        // 12/1/16; This was giving a compiler crash here until I fiddled with this.
        // Original code:
        // return self.initialValue.mutableCopy() as! NSMutableArray
        // See also: http://stackoverflow.com/questions/24222644/swift-compiler-segmentation-fault-when-building
        
        let arrayInitialValue = self.initialValue as! NSMutableArray
        let copy = NSMutableArray(array: arrayInitialValue);
        return copy
    }
}

@objc open class SMPersistVars : NSObject {
    // Singleton class.
    fileprivate static let theSession = SMPersistVars()
    
    // I have this as a class function and not a public static property to enable access from Objective-C
    open class func session() -> SMPersistVars {
        return self.theSession
    }
    
    // The names of all the defaults. Just held in RAM so we can do a reset of all of the items stored in NSUserDefaults and KeyChain if needed.
    fileprivate var userDefaultNames = Set<String>()
    fileprivate var keyChainNames = Set<String>()

    fileprivate override init() {
        super.init()
    }
    
    open func reset() {
        for name in self.userDefaultNames {
            self.resetUserDefaults(name)
        }
        
        self.saveUserDefaults()
        
        for name in self.keyChainNames {
            self.resetKeyChain(name)
        }
    }
    
    fileprivate func resetUserDefaults(_ name:String) {
        UserDefaults.standard.removeObject(forKey: name)
        self.saveUserDefaults()
    }
    
    fileprivate func saveUserDefaults() {
        UserDefaults.standard.synchronize()
    }
    
    fileprivate func resetKeyChain(_ name:String) {
        if !KeyChain.removeSecureToken(forService: name, account: KEYCHAIN_ACCOUNT) {
            Log.msg("Failed on removeSecureTokenForService: name: \(name); account: \(KEYCHAIN_ACCOUNT)")
        }
    }
}

// NSObject so I can access from Obj-C
open class SMPersistVarTest : NSObject {
#if DEBUG
    static let TEST_BOOL = SMPersistItemBool(name: "TestBool", initialBoolValue:true, persistType: .userDefaults)
    static let TEST_INT = SMPersistItemInt(name: "TestInt", initialIntValue:0,
        persistType: .userDefaults)
    static let TEST_SET = SMPersistItemSet(name: "TestSet", initialSetValue:NSMutableSet(), persistType: .userDefaults)
    static let TEST_STRING = SMPersistItemString(name: "TestString", initialStringValue:"", persistType: .userDefaults)
    static let TEST_DICT = SMPersistItemDict(name: "TestDict", initialDictValue:[:], persistType: .userDefaults)
    static let TEST_DICT2 = SMPersistItemDict(name: "TestDict2", initialDictValue:[:], persistType: .userDefaults)
    
    static let TEST_BOOL_KEYCHAIN = SMPersistItemBool(name: "TestBool", initialBoolValue:true, persistType: .keyChain)
    static let TEST_INT_KEYCHAIN = SMPersistItemInt(name: "TestInt", initialIntValue:0,
        persistType: .keyChain)
    static let TEST_SET_KEYCHAIN = SMPersistItemSet(name: "TestSet", initialSetValue:NSMutableSet(), persistType: .keyChain)
    static let TEST_STRING_KEYCHAIN = SMPersistItemString(name: "TestString", initialStringValue:"", persistType: .keyChain)
    static let TEST_DICT_KEYCHAIN = SMPersistItemDict(name: "TestDict", initialDictValue:[:], persistType: .keyChain)
    
    private enum TestType {
        case JustPrint
        case ChangeValues
        case Reset
    }
    
    public class func run() {
        func printValues(messagePrefix:String) {
            print("\(messagePrefix): self.TEST_BOOL.boolValue: \(self.TEST_BOOL.boolValue)")
            print("\(messagePrefix): self.TEST_INT.intValue: \(self.TEST_INT.intValue)")
            print("\(messagePrefix): self.TEST_SET.setValue: \(self.TEST_SET.setValue)")
            print("\(messagePrefix): self.TEST_STRING.stringValue: \(self.TEST_STRING.stringValue)")
            print("\(messagePrefix): self.TEST_DICT.dictValue: \(self.TEST_DICT.dictValue)")
            print("\(messagePrefix): self.TEST_DICT2.dictValue: \(self.TEST_DICT2.dictValue)")

            print("\(messagePrefix): self.TEST_BOOL_KEYCHAIN.boolValue: \(self.TEST_BOOL_KEYCHAIN.boolValue)")
            print("\(messagePrefix): self.TEST_INT_KEYCHAIN.intValue: \(self.TEST_INT_KEYCHAIN.intValue)")
            print("\(messagePrefix): self.TEST_SET_KEYCHAIN.setValue: \(self.TEST_SET_KEYCHAIN.setValue)")
            print("\(messagePrefix): self.TEST_STRING_KEYCHAIN.stringValue: \(self.TEST_STRING_KEYCHAIN.stringValue)")
            print("\(messagePrefix): self.TEST_DICT_KEYCHAIN.dictValue: \(self.TEST_DICT_KEYCHAIN.dictValue)")
        }

        //printValues("before")

        let testType:TestType = .ChangeValues
        
        switch (testType) {
        case .JustPrint:
            break // nop
            
        case .ChangeValues:
            self.TEST_BOOL.boolValue = false
            self.TEST_INT.intValue += 1
            self.TEST_SET.setValue.add(NSDate())
            self.TEST_STRING.stringValue = "New user defaults string"
            self.TEST_DICT.dictValue["someKey"] = "someValue"
            self.TEST_DICT2.dictValue["someKey"] = true
            testChangeVar(dictVar: self.TEST_DICT2)
            Log.msg("\(self.TEST_DICT2.dictValue)")
            self.TEST_BOOL_KEYCHAIN.boolValue = false
            self.TEST_INT_KEYCHAIN.intValue = 10
            self.TEST_SET_KEYCHAIN.setValue.add("new")
            self.TEST_STRING_KEYCHAIN.stringValue = "New keychain string"
            self.TEST_DICT_KEYCHAIN.dictValue["someKey"] = "someValue"
            
        case .Reset:
            self.TEST_BOOL.reset()
            self.TEST_INT.reset()
            self.TEST_SET.reset()
            self.TEST_STRING.reset()
            self.TEST_DICT.reset()
            self.TEST_DICT2.reset()
            self.TEST_BOOL_KEYCHAIN.reset()
            self.TEST_INT_KEYCHAIN.reset()
            self.TEST_SET_KEYCHAIN.reset()
            self.TEST_STRING_KEYCHAIN.reset()
            self.TEST_DICT_KEYCHAIN.reset()
        }
        
        printValues(messagePrefix: "after")
    }
    
    class func testChangeVar(dictVar:SMPersistItemDict) {
        dictVar.dictValue["someKey2"] = true
    }
    
#endif
}
