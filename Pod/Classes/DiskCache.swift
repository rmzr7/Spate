//
//  DiskCache.swift
//  Spate
//
//  Created by Rameez Remsudeen  on 7/22/15.
//  Copyright © 2015 Spate. All rights reserved.
//

import Foundation

public class DiskCache {
    public lazy var diskReadQueue:dispatch_queue_t = dispatch_queue_create("io.spate.diskCache.readQueue", DISPATCH_QUEUE_SERIAL)
    public lazy var diskWriteQueue:dispatch_queue_t = dispatch_queue_create("io.spate.diskCache.writeQueue", DISPATCH_QUEUE_SERIAL)
    
    var baseCacheDirectory:NSString = {
        let cacheDir = NSSearchPathForDirectoriesInDomains(.CachesDirectory, .UserDomainMask, true)[0] as NSString
        return cacheDir.stringByAppendingPathComponent("io.spate.diskCache")
        }()
    
    static let fileManager = NSFileManager.defaultManager()
    
    var directory:NSString
    var name:String
    var size:UInt64 = 0
    var capacity:UInt64 = 0 {
        didSet {
            dispatch_async(self.diskWriteQueue) { () -> Void in
                self.updateCapacity()
            }
        }
    }
    
    init(maxCapacity:UInt64 = UINT64_MAX, name:String) {
        self.name = name
        self.directory = baseCacheDirectory.stringByAppendingPathComponent(name)
        dispatch_async(diskWriteQueue) { () -> Void in
            
            dispatch_sync(self.diskWriteQueue, { () -> Void in
                if !DiskCache.fileManager.fileExistsAtPath(self.directory as String) {
                    try! DiskCache.fileManager.createDirectoryAtPath(self.directory as String, withIntermediateDirectories: true, attributes: nil)
                }
            })
            
            self.computeSize()
            self.updateCapacity()
        }
    }
    
    func object(forKey key:String) -> CacheObject? {
        dispatch_sync(diskReadQueue) { () -> Void in
            let object:CacheObject?
            let path = self.pathForKey(key)
            if DiskCache.fileManager.fileExistsAtPath(path as String) {
                object = NSKeyedUnarchiver.unarchiveObjectWithFile(path as String) as? CacheObject
                self.updateLastAccessedDate(key)
            }
            //            return object
        }
        
        return CacheObject(value: "ss", expiration: NSDate())
    }
    
    func setObject(object:CacheObject, forKey key:String) {
        
    }
    
    func removeObjectForKey(key:String) {
        dispatch_async(diskWriteQueue) { () -> Void in
            let path = self.pathForKey(key)
            self.removeFileAtPath(path as String)
        }
    }
    
    func updateLastAccessedDate(key:String) {
        dispatch_async(diskWriteQueue) { () -> Void in
            let path = self.pathForKey(key)
            if DiskCache.fileManager.fileExistsAtPath(path as String) {
                do {
                    try DiskCache.fileManager.setAttributes([NSFileModificationDate:NSDate()], ofItemAtPath: path as String)
                } catch let error as NSError {
                    print("Failed to update modification date of cache at path:\(path), \(error.localizedDescription)")
                }
                catch {
                    print("Error not caught with NSError: Failed to update modification date of cache at path:\(path)")
                }
            }
            
        }
    }
    
    //MARK:- Private Funcs
    func pathForKey(key:String) -> NSString{
        let sanitizedKey = sanitizeKey(key)
        
        let path = (directory.stringByAppendingPathComponent(sanitizedKey as String) as NSString).stringByAppendingPathExtension("cache")
        return path!
    }
    
    
    func sanitizeKey(key:String) -> NSString {
        let regex = try! NSRegularExpression(pattern: "[^a-zA-Z0-9_]+", options: NSRegularExpressionOptions())
        let range = NSRange(location: 0, length: key.characters.count)
        let sanitizedKey = regex.stringByReplacingMatchesInString(key, options: NSMatchingOptions(), range: range, withTemplate: "_")
        return sanitizedKey
    }
    
    /// computes the total size of the cache
    private func computeSize() {
        do {
            let items = try DiskCache.fileManager.contentsOfDirectoryAtPath(directory as String)
            for item in items {
                let dir = directory.stringByAppendingPathComponent(item)
                do {
                    let attribs = try DiskCache.fileManager.attributesOfItemAtPath(dir) as NSDictionary
                    size += attribs.fileSize()
                } catch let error as NSError {
                    print("error:\(error.localizedDescription) when accessing attributes of item at Path:\(directory)")
                }
            }
        } catch let error as NSError {
            print("error:\(error.localizedDescription) while getting contents of directory at path \(directory)")
        }
    }
    
    /// keeps cache within capacity
    private func updateCapacity() {
        if self.size <= self.capacity {
            return
        }
        
        let dirURL = NSURL(fileURLWithPath: directory as String)
        
        do {
            let fileURLs = try DiskCache.fileManager.contentsOfDirectoryAtURL(dirURL, includingPropertiesForKeys: [NSURLContentModificationDateKey], options: NSDirectoryEnumerationOptions.SkipsSubdirectoryDescendants)
            let sortedURLs = fileURLs.sort({ (url1, url2) -> Bool in
                var date1:AnyObject?
                try! url1.getResourceValue(&date1, forKey:NSURLContentModificationDateKey)
                
                var date2:AnyObject?
                try! url2.getResourceValue(&date2, forKey:NSURLContentModificationDateKey)
                
                return (date1 as! NSDate) < (date2 as! NSDate)
            })
            
            for url in sortedURLs {
                removeFileAtPath(url.path!)
                
                if self.size <= self.capacity {
                    break
                }
            }
            
        } catch let error as NSError  {
            print("error accessingFileURL: \(error.localizedDescription) for directory: \(directory)")
        }
    }
    
    private func removeFileAtPath(path:String) {
        do {
            let attribs = try DiskCache.fileManager.attributesOfItemAtPath(directory as String) as NSDictionary
            let fileSize = attribs.fileSize()
            do {
                try DiskCache.fileManager.removeItemAtPath(directory as String)
                self.size -= fileSize
                
            } catch let error as NSError {
                print("error:\(error.localizedDescription) removing item at path \(directory) ")
            }
        } catch let error as NSError {
            print("error:\(error.localizedDescription) when accessing attributes of item at Path:\(directory)")
        }
    }
}

internal func < (lhs: NSDate, rhs: NSDate) -> Bool {
    return lhs.compare(rhs) == NSComparisonResult.OrderedAscending
}