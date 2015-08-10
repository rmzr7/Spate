//
//  CacheObject.swift
//  Spate
//
//  Created by Rameez Remsudeen  on 7/22/15.
//  Copyright © 2015 Spate. All rights reserved.
//

import Foundation

class CacheObject:NSObject, NSCoding {
    
    let value:AnyObject
    var expiration:NSDate
    
    init(value:AnyObject, expiration:NSDate){
        self.value = value
        self.expiration = expiration
    }
    
    required init?(coder aDecoder: NSCoder) {
        value = aDecoder.decodeObjectForKey("value") as AnyObject!
        expiration = aDecoder.decodeObjectForKey("expiration") as! NSDate
        super.init()
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(value, forKey: "value")
        aCoder.encodeObject(expiration, forKey: "expiration")
    }
    
    func hasExpired() -> Bool {
        return expiration.timeIntervalSinceNow < 0
    }
}
