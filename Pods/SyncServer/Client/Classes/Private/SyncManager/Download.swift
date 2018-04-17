//
//  Download.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/23/17.
//
//

import Foundation
import SMCoreLib
import SyncServer_Shared

class Download {
    var desiredEvents:EventDesired!
    weak var delegate:SyncServerDelegate?
    
    static let session = Download()
    
    private init() {
    }
    
    enum OnlyCheckCompletion {
    case checkResult(downloadSet: Directory.DownloadSet, MasterVersionInt?)
    case error(SyncServerError)
    }
    
    // TODO: *0* while this check is occurring, we want to make sure we don't have a concurrent check operation.
    // Doesn't create DownloadFileTracker's or update MasterVersion.
    func onlyCheck(completion:((OnlyCheckCompletion)->())? = nil) {
        
        Log.msg("Download.onlyCheckForDownloads")
        
        ServerAPI.session.fileIndex { (fileIndex, masterVersion, error) in
            guard error == nil else {
                completion?(.error(error!))
                return
            }
            
            // Make sure the mime types we get back from the server are known to the client.
            for file in fileIndex! {
                guard let fileMimeTypeString = file.mimeType,
                    let _ = MimeType(rawValue: fileMimeTypeString) else {
                        Log.error("Unknown mime type from server: \(String(describing: file.mimeType))")
                    completion?(.error(.badMimeType))
                    return
                }
            }

            var completionResult:OnlyCheckCompletion!
            
            CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                do {
                    let downloadSet =
                        try Directory.session.checkFileIndex(serverFileIndex: fileIndex!)
                    completionResult =
                        .checkResult(downloadSet: downloadSet, masterVersion)
                } catch (let error) {
                    completionResult = .error(.coreDataError(error))
                }
                
                completion?(completionResult)
            }
        }
    }
    
    enum CheckCompletion {
    case noDownloadsOrDeletionsAvailable
    case downloadsAvailable(numberOfContentDownloads:Int, numberOfDownloadDeletions:Int)
    case error(SyncServerError)
    }
    
    // TODO: *0* while this check is occurring, we want to make sure we don't have a concurrent check operation.
    // Creates DownloadFileTracker's to represent files that need downloading/download deleting. Updates MasterVersion with the master version on the server.
    func check(completion:((CheckCompletion)->())? = nil) {
        onlyCheck() { onlyCheckResult in
            switch onlyCheckResult {
            case .error(let error):
                completion?(.error(error))
            
            case .checkResult(downloadSet: let downloadSet, let masterVersion):
                var completionResult:CheckCompletion!

                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    Singleton.get().masterVersion = masterVersion!
                    
                    if downloadSet.allFiles().count > 0 {
                        for file in downloadSet.allFiles() {
                            let dft = DownloadFileTracker.newObject() as! DownloadFileTracker
                            dft.fileUUID = file.fileUUID
                            dft.fileVersion = file.fileVersion
                            dft.mimeType = file.mimeType
                            
                            if downloadSet.downloadFiles.contains(file) {
                                dft.operation = .file
                            }
                            else if downloadSet.downloadDeletions.contains(file) {
                                dft.operation = .deletion
                            }
                            else if downloadSet.downloadAppMetaData.contains(file) {
                                dft.operation = .appMetaData
                            }
                            else {
                                completionResult = .error(.generic("Internal Error"))
                                return
                            }
                            
                            dft.appMetaDataVersion = file.appMetaDataVersion
                            
                            if file.creationDate != nil {
                                dft.creationDate = file.creationDate! as NSDate
                                dft.updateDate = file.updateDate! as NSDate
                            }
                        }
                        
                        completionResult = .downloadsAvailable(
                            numberOfContentDownloads:downloadSet.downloadFiles.count + downloadSet.downloadAppMetaData.count,
                            numberOfDownloadDeletions:downloadSet.downloadDeletions.count)
                    }
                    else {
                        completionResult = .noDownloadsOrDeletionsAvailable
                    }
                    
                    do {
                        try CoreData.sessionNamed(Constants.coreDataName).context.save()
                    } catch (let error) {
                        completionResult = .error(.coreDataError(error))
                        return
                    }
                } // End performAndWait
                
                completion?(completionResult)
            }
        }
    }

    enum NextResult {
    case started
    case noDownloadsOrDeletions
    case allDownloadsCompleted
    case error(SyncServerError)
    }
    
    enum NextCompletion {
    case fileDownloaded(url:SMRelativeLocalURL, attr:SyncAttributes, dft: DownloadFileTracker)
    case appMetaDataDownloaded(attr:SyncAttributes, dft: DownloadFileTracker)
    case masterVersionUpdate
    case error(SyncServerError)
    }
    
    // Starts download of next file or appMetaData, if there is one. There should be no files/appMetaData downloading already. Only if .started is the NextResult will the completion handler be called. With a masterVersionUpdate response for NextCompletion, the MasterVersion Core Data object is updated by this method, and all the DownloadFileTracker objects have been reset.
    func next(first: Bool = false, completion:((NextCompletion)->())?) -> NextResult {
        var masterVersion:MasterVersionInt!
        var nextResult:NextResult?
        var downloadFile:FilenamingWithAppMetaDataVersion!
        var nextToDownload:DownloadFileTracker!
        var numberContentDownloads = 0
        var numberDownloadDeletions = 0
        var operation:FileTracker.Operation!
        
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            let dfts = DownloadFileTracker.fetchAll()
            guard dfts.count != 0 else {
                nextResult = .noDownloadsOrDeletions
                return
            }
            
            numberDownloadDeletions = (dfts.filter {$0.operation.isDeletion}).count
            numberContentDownloads = dfts.count - numberDownloadDeletions

            let alreadyDownloading = dfts.filter {$0.status == .downloading}
            guard alreadyDownloading.count == 0 else {
                Log.error("Already downloading a file!")
                nextResult = .error(.alreadyDownloadingAFile)
                return
            }
            
            let notStarted = dfts.filter {$0.status == .notStarted && $0.operation.isContents}
            guard notStarted.count != 0 else {
                nextResult = .allDownloadsCompleted
                return
            }
            
            masterVersion = Singleton.get().masterVersion

            nextToDownload = notStarted[0]
            nextToDownload.status = .downloading
            
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch (let error) {
                nextResult = .error(.coreDataError(error))
            }
            
            // Need this inside the `performAndWait` to bridge the gap without an NSManagedObject
            downloadFile = FilenamingWithAppMetaDataVersion(fileUUID: nextToDownload.fileUUID, fileVersion: nextToDownload.fileVersion, appMetaDataVersion: nextToDownload.appMetaDataVersion)
            operation = nextToDownload.operation
        }
        
        guard nextResult == nil else {
            return nextResult!
        }
        
        if first {
            EventDesired.reportEvent( .willStartDownloads(numberContentDownloads: UInt(numberContentDownloads), numberDownloadDeletions: UInt(numberDownloadDeletions)), mask: desiredEvents, delegate: delegate)
        }
        
        switch operation! {
        case .file:
            doDownloadFile(masterVersion: masterVersion, downloadFile: downloadFile, nextToDownload: nextToDownload, completion:completion)
        
        case .appMetaData:
            doAppMetaDataDownload(masterVersion: masterVersion, downloadFile: downloadFile, nextToDownload: nextToDownload, completion:completion)
            
        case .deletion:
            assert(false, "Bad puppy!")
        }
        
        return .started
    }
    
    private func doDownloadFile(masterVersion: MasterVersionInt, downloadFile: FilenamingWithAppMetaDataVersion, nextToDownload: DownloadFileTracker, completion:((NextCompletion)->())?) {
    
        ServerAPI.session.downloadFile(fileNamingObject: downloadFile, serverMasterVersion: masterVersion) {[weak self] (result, error)  in
        
            // Don't hold the performAndWait while we do completion-- easy to get a deadlock!

            guard error == nil else {
                self?.doError(nextToDownload: nextToDownload, error: .otherError(error!), completion: completion)
                return
            }
            
            switch result! {
            case .success(let downloadedFile):
                var nextCompletionResult:NextCompletion!
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    // 3/23/18; Because we're not getting appMetaData in the FileIndex any more.
                    nextToDownload.appMetaData = downloadedFile.appMetaData?.contents
                    nextToDownload.appMetaDataVersion = downloadedFile.appMetaData?.version
                
                    // 9/16/17; Not really crucial since we'll be deleting this DownloadFileTracker quickly. But, useful for testing.
                    nextToDownload.status = .downloaded
                    
                    CoreData.sessionNamed(Constants.coreDataName).saveContext()
                    
                    // TODO: Not using downloadedFile.fileSizeBytes. Why?
                    let mimeType = MimeType(rawValue: nextToDownload.mimeType!)!
                    var attr = SyncAttributes(fileUUID: nextToDownload.fileUUID, mimeType: mimeType, creationDate: nextToDownload.creationDate! as Date, updateDate: nextToDownload.updateDate! as Date)
                    attr.appMetaData = downloadedFile.appMetaData?.contents
                    attr.creationDate = nextToDownload.creationDate as Date?
                    attr.updateDate = nextToDownload.updateDate as Date?
                    
                    // Not removing nextToDownload yet because I haven't called the client completion callback yet-- will do the deletion after that.
                    
                    nextCompletionResult = .fileDownloaded(url:downloadedFile.url, attr:attr, dft: nextToDownload)
                }
        
                completion?(nextCompletionResult)
                
            case .serverMasterVersionUpdate(let masterVersionUpdate):
                self?.doMasterVersionUpdate(masterVersionUpdate: masterVersionUpdate, completion:completion)
            }
        }
    }
    
    private func doAppMetaDataDownload(masterVersion: MasterVersionInt, downloadFile: FilenamingWithAppMetaDataVersion, nextToDownload: DownloadFileTracker, completion:((NextCompletion)->())?) {
    
        assert(downloadFile.appMetaDataVersion != nil)

        ServerAPI.session.downloadAppMetaData(appMetaDataVersion: downloadFile.appMetaDataVersion!, fileUUID: downloadFile.fileUUID, serverMasterVersion: masterVersion) {[weak self] result in

            switch result {
            case .success(.appMetaData(let appMetaData)):
                var nextCompletionResult:NextCompletion!
                CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
                    nextToDownload.appMetaData = appMetaData
                    nextToDownload.status = .downloaded
                    CoreData.sessionNamed(Constants.coreDataName).saveContext()
                    
                    let mimeType = MimeType(rawValue: nextToDownload.mimeType!)!
                    var attr = SyncAttributes(fileUUID: nextToDownload.fileUUID, mimeType: mimeType, creationDate: nextToDownload.creationDate! as Date, updateDate: nextToDownload.updateDate! as Date)
                    attr.appMetaData = appMetaData
                    attr.creationDate = nextToDownload.creationDate as Date?
                    attr.updateDate = nextToDownload.updateDate as Date?
                    
                    // Not removing nextToDownload yet because I haven't called the client completion callback yet-- will do the deletion after that.
                    
                    nextCompletionResult = .appMetaDataDownloaded(attr:attr, dft: nextToDownload)
                }
        
                completion?(nextCompletionResult)
                
            case .success(.serverMasterVersionUpdate(let masterVersionUpdate)):
                self?.doMasterVersionUpdate(masterVersionUpdate: masterVersionUpdate, completion:completion)
                
            case .error(let error):
                self?.doError(nextToDownload: nextToDownload, error: .otherError(error), completion: completion)
            }
        }
    }
    
    private func doError(nextToDownload: DownloadFileTracker, error:SyncServerError, completion:((NextCompletion)->())?) {
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            nextToDownload.status = .notStarted
            
            // Not going to check for exceptions on saveContext; we already have an error.
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }

        Log.error("Error: \(String(describing: error))")
        completion?(.error(error))
    }
    
    private func doMasterVersionUpdate(masterVersionUpdate: MasterVersionInt, completion:((NextCompletion)->())?) {
        // 9/18/17; We're doing downloads in an eventually consistent manner. See http://www.spasticmuffin.biz/blog/2017/09/15/making-downloads-more-flexible-in-the-syncserver/
        // The following will remove any outstanding DownloadFileTrackers. If we've already downloaded a file-- those dft's will have been removed already. This is part of our eventually consistent operation. It is possible that some of the already downloaded files may need to be deleted (or updated, when we get to multiple file versions).
        
        var nextCompletionResult:NextCompletion!
        CoreData.sessionNamed(Constants.coreDataName).performAndWait() {
            DownloadFileTracker.removeAll()
            Singleton.get().masterVersion = masterVersionUpdate
            
            do {
                try CoreData.sessionNamed(Constants.coreDataName).context.save()
            } catch (let error) {
                nextCompletionResult = .error(.coreDataError(error))
                return
            }
            
            nextCompletionResult = .masterVersionUpdate
        }

        completion?(nextCompletionResult)
    }
}
