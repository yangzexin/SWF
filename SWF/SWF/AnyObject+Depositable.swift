//
//  NSObject+DepositableSupport.swift
//  SWF
//
//  Created by yangzexin on 5/13/15.
//  Copyright (c) 2015 yangzexin. All rights reserved.
//

import Foundation
#if os(iOS)
import UIKit
#endif

public func deposit(to target: AnyObject, with depositable: Depositable) -> Depositable {
    return deposit(to:target, with:depositable, id: nil)
}

internal func _deposit<T: Depositable> (to target: AnyObject, with depositable: T, var #id: String?) -> T {
    return deposit(to: target, with: depositable, id: id) as! T
}

public func deposit(to target: AnyObject, with depositable: Depositable, var #id: String?) -> Depositable {
    objc_sync_enter(target)
    
    if id == nil {
        id = String(stringInterpolationSegment: NSDate.timeIntervalSinceReferenceDate())
    }
    
    keyIdValueDepositable(target).setObject(depositable, forKey: id!)
    depositable.depositableDidAdd()
    
    objc_sync_exit(target)
    
    return depositable
}

public func deposited(from target: AnyObject, #id: String) -> Depositable? {
    objc_sync_enter(target)
    
    var depositable = keyIdValueDepositable(target).objectForKey(id) as? Depositable
    
    objc_sync_exit(target)
    
    return depositable
}

public func removeDeposited(from target: AnyObject, #id: String) {
    objc_sync_enter(target)
    
    var KIVD = keyIdValueDepositable(target)
    
    var object: AnyObject? = KIVD.objectForKey(id)
    if let depositable = object as? Depositable {
        depositable.depositableWillRemove()
        KIVD.removeObjectForKey(id)
    }
    
    objc_sync_exit(target)
}

private func keyIdValueDepositable(target: AnyObject) -> NSMutableDictionary {
    var keyIdValueDepositable: NSMutableDictionary?
    
    objc_sync_enter(target)
    
    if let dict = getAssociatedObject(from: target, key: "_depositable_support_keyIdValueDepositable") as? NSMutableDictionary {
        keyIdValueDepositable = dict
    } else {
        keyIdValueDepositable = NSMutableDictionary()
        setAssociatedObject(to:target, key: "_depositable_support_keyIdValueDepositable", with: keyIdValueDepositable!)
        #if os(iOS)
            let observerContext = NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationDidReceiveMemoryWarningNotification, object: nil, queue: nil, usingBlock: {
                [weak keyIdValueDepositable, weak target] (notification: NSNotification!) -> Void in
                if (keyIdValueDepositable != nil) {
                    handleMemoryWarning(target!, keyIdValueDepositable!)
                }
            })
            
            addDiedObserver(target: target, id: "_depositable_support_removeNotificationCenterObserver", {
                [weak keyIdValueDepositable] () -> () in
                NSNotificationCenter.defaultCenter().removeObserver(observerContext)
                if let wkeyIdValueDepositable = keyIdValueDepositable {
                    notifyAllDepositables(wkeyIdValueDepositable)
                } else {
                    println("unexpected runtime error: nil keyIdValueDepositable")
                }
            })
        #else
            addDiedObserver(target: target, id: "_depositable_support_removeNotificationCenterObserver", { () -> () in
                if let wkeyIdValueDepositable = keyIdValueDepositable {
                    notifyAllDepositables(wkeyIdValueDepositable)
                } else {
                    println("unexpected runtime error: nil keyIdValueDepositable")
                }
            })
        #endif
    }
    
    objc_sync_exit(target)
    
    return keyIdValueDepositable!
}

private func notifyAllDepositables(keyIdValueDepositable: NSMutableDictionary) {
    for (_, value) in keyIdValueDepositable {
        var depositable = value as! Depositable
        depositable.depositableWillRemove()
    }
}

private func handleMemoryWarning(target:AnyObject, keyIdValueDepositable: NSMutableDictionary) {
    objc_sync_enter(target)
    
    var removingKeys = NSMutableArray()
    
    for key in keyIdValueDepositable.allKeys {
        var depositable = keyIdValueDepositable.objectForKey(key) as! Depositable
        if depositable.shouldRemoveDepositable() {
            depositable.depositableWillRemove()
            removingKeys.addObject(key)
        }
    }
    
    for key in removingKeys {
        keyIdValueDepositable.removeObjectForKey(key)
    }
    
    objc_sync_exit(target)
}
