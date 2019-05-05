//
//  FileObject+CoreDataProperties.swift
//  SharedImages
//
//  Created by Christopher G Prince on 5/4/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//
//

import Foundation
import CoreData


extension FileObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FileObject> {
        return NSFetchRequest<FileObject>(entityName: "FileObject")
    }

    @NSManaged public var fileGroupUUID: String?
    @NSManaged public var goneReasonInternal: String?
    @NSManaged public var mimeType: String?
    @NSManaged public var readProblem: Bool
    @NSManaged public var sharingGroupUUID: String?
    @NSManaged public var urlInternal: NSData?
    @NSManaged public var uuid: String?

}
