//
//  CoreData.swift
//  SMCoreLib
//
//  Created by Christopher Prince on 2/22/16.
//  Copyright © 2016 Spastic Muffin, LLC. All rights reserved.
//

// Swift methods building on the CoreData Objective-C class.

import Foundation

public extension CoreData {

    public class func fetchObjectWithUUID(_ uuid:String, usingUUIDKey uuidKey:String, fromEntityName entityName: String, coreDataSession session:CoreData) -> NSManagedObject? {
        var objs:[NSManagedObject]?

        do {
            let result = try session.fetchObjects(withEntityName: entityName) { (request: NSFetchRequest!) in
                // This doesn't seem to work
                //NSString *predicateFormat = [NSString stringWithFormat:@"(%@ == %%s)", UUID_KEY];
                // See https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Predicates/Articles/pSyntax.html
                // And http://stackoverflow.com/questions/15505208/creating-nspredicate-dynamically-by-setting-the-key-programmatically
            
                request.predicate = NSPredicate(format: "(%K == %@)", uuidKey, uuid)
            }
            
            objs = result as? [NSManagedObject]
            
        } catch (let error) {
            Log.msg("\(error)")
        }
        
        var obj:NSManagedObject?
        
        if nil != objs {
            if objs!.count > 1 {
                Log.error("There is more than one object with that UUID: \(uuid)");
            }
            else if objs!.count == 1 {
                obj = objs![0]
            }
            
            // Could still have 0 objs-- returning nil in that case.
        }
        
        return obj
    }
    
    public class func getSMRelativeLocalURL(fromCoreDataProperty coreDataProperty: Data?) -> SMRelativeLocalURL? {
        if nil == coreDataProperty {
            return nil
        }
        
        let url = NSKeyedUnarchiver.unarchiveObject(with: coreDataProperty!) as? SMRelativeLocalURL
        Assert.If(url == nil, thenPrintThisString: "getSMRelativeLocalURL: Yikes: No URL!")
        return url
    }
    
    public class func setSMRelativeLocalURL(_ newValue:SMRelativeLocalURL?, toCoreDataProperty coreDataProperty: inout Data?, coreDataSessionName:String) {
    
        if newValue == nil {
            coreDataProperty = nil
        }
        else {
            coreDataProperty = NSKeyedArchiver.archivedData(withRootObject: newValue!)
        }
        
        CoreData.sessionNamed(coreDataSessionName).saveContext()
    }
}
