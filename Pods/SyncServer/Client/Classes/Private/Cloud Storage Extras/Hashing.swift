//
//  Hashing.swift
//  SyncServer
//
//  Created by Christopher G Prince on 10/21/18.
//

// This is needed for generating check sums for uploading/downloading via Google Drive and Dropbox. Since it's needed by clients even when they are not using the relevant sign-ins, it must always be part of the client code.

import Foundation
import SMCoreLib
import SyncServer_Shared
import FileMD5Hash

// CommonCrypto is only available with Xcode 10 for import into Swift; see also https://stackoverflow.com/questions/25248598/importing-commoncrypto-in-a-swift-framework
import CommonCrypto

class Hashing {
    // From https://stackoverflow.com/questions/25388747/sha256-in-swift
    private static func sha256(data : Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0, CC_LONG(data.count), &hash)
        }
        return Data(bytes: hash)
    }
    
    private static let dropboxBlockSize = 1024 * 1024 * 4

    // Method: https://www.dropbox.com/developers/reference/content-hash
    static func generateDropbox(fromLocalFile localFile: URL) -> String? {

        guard let inputStream = InputStream(url: localFile) else {
            Log.msg("Error opening input stream: \(localFile)")
            return nil
        }

        var inputBuffer = [UInt8](repeating: 0, count: dropboxBlockSize)
        inputStream.open()
        defer {
            inputStream.close()
        }
        
        var concatenatedSHAs = Data()
        
        while true {
            let length = inputStream.read(&inputBuffer, maxLength: dropboxBlockSize)
            if length == 0 {
                // EOF
                break
            }
            else if length < 0 {
                return nil
            }
            
            let dataBlock = Data(bytes: inputBuffer, count: length)
            let sha = sha256(data: dataBlock)
            concatenatedSHAs.append(sha)
        }
        
        let finalSHA = sha256(data: concatenatedSHAs)
        let hexString = finalSHA.map { String(format: "%02hhx", $0) }.joined()

        return hexString
    }
    
    static func generateDropbox(fromData data: Data) -> String? {
        var concatenatedSHAs = Data()
        
        var remainingLength = data.count
        if remainingLength == 0 {
            return nil
        }
        
        var startIndex = data.startIndex

        while true {
            let nextBlockSize = min(remainingLength, dropboxBlockSize)
            let endIndex = startIndex.advanced(by: nextBlockSize)
            let range = startIndex..<endIndex
            startIndex = endIndex
            remainingLength -= nextBlockSize

            let sha = sha256(data: data[range])
            concatenatedSHAs.append(sha)
            
            if remainingLength == 0 {
                break
            }
        }
        
        let finalSHA = sha256(data: concatenatedSHAs)
        let hexString = finalSHA.map { String(format: "%02hhx", $0) }.joined()

        return hexString
    }
    
    private static let googleBufferSize = 1024 * 1024
    
    // I'm having problems with this computing checksums in some cases. Using FileMD5Hash instead.
    // From https://stackoverflow.com/questions/42935148/swift-calculate-md5-checksum-for-large-files
    static func generateMD5(fromURL url: URL) -> String? {
        do {
            // Open file for reading:
            let file = try FileHandle(forReadingFrom: url)
            defer {
                file.closeFile()
            }

            // Create and initialize MD5 context:
            var context = CC_MD5_CTX()
            CC_MD5_Init(&context)

            // Read up to `bufferSize` bytes, until EOF is reached, and update MD5 context:
            while autoreleasepool(invoking: {
                let data = file.readData(ofLength: googleBufferSize)
                print("data.count: \(data.count)")
                if data.count > 0 {
                    data.withUnsafeBytes {
                        _ = CC_MD5_Update(&context, $0, numericCast(data.count))
                    }
                    return true // Continue
                } else {
                    return false // End of file
                }
            }) { }

            // Compute the MD5 digest:
            var digest = Data(count: Int(CC_MD5_DIGEST_LENGTH))
            digest.withUnsafeMutableBytes {
                _ = CC_MD5_Final($0, &context)
            }

            let hexString = digest.map { String(format: "%02hhx", $0) }.joined()
            return hexString

        } catch {
            Log.msg("Cannot open file: " + error.localizedDescription)
            return nil
        }
    }
    
    static func generateMD5(fromData data: Data) -> String? {
        if data.count == 0 {
            return nil
        }

        // Create and initialize MD5 context:
        var context = CC_MD5_CTX()
        CC_MD5_Init(&context)

        data.withUnsafeBytes {
            _ = CC_MD5_Update(&context, $0, numericCast(data.count))
        }

        // Compute the MD5 digest:
        var digest = Data(count: Int(CC_MD5_DIGEST_LENGTH))
        digest.withUnsafeMutableBytes {
            _ = CC_MD5_Final($0, &context)
        }

        let hexString = digest.map { String(format: "%02hhx", $0) }.joined()
        return hexString
    }
    
    static func hashOf(url: URL, for cloudStorageType: CloudStorageType) -> String? {
        switch cloudStorageType {
        case .Dropbox:
            return generateDropbox(fromLocalFile: url)
        case .Google:
            return FileHash.md5HashOfFile(atPath: url.path)
        }
    }
}
