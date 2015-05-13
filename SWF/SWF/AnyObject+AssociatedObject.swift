//
//  NSObject+AssociatedObject.swift
//  SFLibs
//
//  Created by yangzexin on 5/11/15.
//  Copyright (c) 2015 yangzexin. All rights reserved.
//

import Foundation
import ObjectiveC

public func setAssociatedObject(to target: AnyObject, #key: NSCopying, with object:AnyObject) {
    AODict(target).setObject(object, forKey: key)
}

public func getAssociatedObject(from target: AnyObject, #key: NSCopying) -> AnyObject? {
    return AODict(target).objectForKey(key)
}

public func removeAssociatedObject(from target: AnyObject, #key: NSCopying) {
    AODict(target).removeObjectForKey(key)
}

private var AssociatedObjectKey = "AssociatedObjectKey";

private func AODict(target: AnyObject) -> NSMutableDictionary {
    var dict: NSMutableDictionary!
    
    objc_sync_enter(target)
    
    if let existsDict = objc_getAssociatedObject(target, &AssociatedObjectKey) as? NSMutableDictionary {
        dict = existsDict
    } else {
        dict = NSMutableDictionary()
        objc_setAssociatedObject(target, &AssociatedObjectKey, dict, UInt(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
    }
    
    objc_sync_exit(target)
    
    return dict
}
