//
//  Cache.swift
//  Spate
//
//  Created by Rameez Remsudeen  on 7/22/15.
//  Copyright © 2015 Spate. All rights reserved.
//

import Foundation

let kDefaultDiskCapacity:UInt64 = 10 * 1024 * 1024

public enum CacheExpiry {
    case Never
    case Seconds(NSTimeInterval)
    case Date(NSDate)
}

public enum CacheType {
    case LeastRecentlyUsed
    case LeastFrequentlyUsed
}

public class Cache<T:NSCoding> {
    let name:String
    let diskCache:DiskCache
    let memCache:NSCache = NSCache()
    var memoryWarningObserver:NSObjectProtocol!
    var cacheType:CacheType
    
    /// designated initializer
    public init (name:String, maxCapacity:UInt64 = kDefaultDiskCapacity, cacheType:CacheType = .LeastFrequentlyUsed) {
        self.name = name
        self.diskCache = DiskCache(maxCapacity: maxCapacity, name: name)
        self.memCache.name = name
        self.cacheType = cacheType
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        memoryWarningObserver = notificationCenter.addObserverForName(UIApplicationDidReceiveMemoryWarningNotification,
            object: nil,
            queue: NSOperationQueue.mainQueue(),
            usingBlock: { [unowned self](notification:NSNotification) -> Void in
                self.didTriggerMemoryWarning
            })
    }
    
    deinit {
        let notifications = NSNotificationCenter.defaultCenter()
        notifications.removeObserver(memoryWarningObserver, name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
    }
    
    public func objectForKey(key:String) -> T? {
        
        if let object = memCache.objectForKey(key) {
            print("obj is \(object)")
        }
        
        guard let object = memCache.objectForKey(key) as? CacheObject else{
            
            let object = diskCache.object(forKey: key) as? T
            return object
        }
        
        diskCache.updateLastAccessedDate(key)
        
        if object.hasExpired() {
            removeObjectForKey(key)
            return nil
        }
        
        return object.value as? T
    }
    
    public func setObject(value:T, forKey key:String, expiry:CacheExpiry = .Never) {
        
        let expiryDate = expiryForCacheExpiry(expiry)
        let object = CacheObject(value: value, expiration: expiryDate)
        print(object)
        memCache.setObject(object, forKey: key)
        diskCache.setObject(object, forKey:key)
        
    }
    
    public func removeObjectForKey(key:String){
        memCache.removeObjectForKey(key)
        diskCache.removeObjectForKey(key)
    }
    
    public subscript(key:String, expiry:CacheExpiry) -> T? {
        get {
            return objectForKey(key)
        }
        set {
            if let value = newValue {
                setObject(value, forKey: key, expiry: expiry)
            } else {
                removeObjectForKey(key)
            }
        }
    }
    
    public subscript(key:String) -> T? {
        get {
            return objectForKey(key)
        }
        set(newValue) {
            if let value = newValue {
                setObject(value, forKey:key)
            } else {
                removeObjectForKey(key)
            }
        }
    }
    
    //MARK: Private vars and funcs
    private func didTriggerMemoryWarning() {
        
    }
    
    private func expiryForCacheExpiry(expiry:CacheExpiry) -> NSDate {
        switch (expiry){
        case .Never:
            return NSDate.distantFuture()
        case .Seconds(let seconds):
            return NSDate().dateByAddingTimeInterval(seconds)
        case .Date(let date):
            return date
        }
    }
}