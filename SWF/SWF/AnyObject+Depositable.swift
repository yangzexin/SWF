//
//  NSObject+DepositableSupport.swift
//  SWF
//
//  Created by yangzexin on 5/13/15.
//  Copyright (c) 2015 yangzexin. All rights reserved.
//

import UIKit

public func deposit<T: Depositable>(to target: AnyObject, with depositable: T) -> T {
    return deposit(to:target, with:depositable, id: nil)
}

public func deposit<T: Depositable>(to target: AnyObject, with depositable: T, var #id: String?) -> T {
    objc_sync_enter(target)
    
    if id == nil {
        id = String(stringInterpolationSegment: NSDate.timeIntervalSinceReferenceDate())
    }
    
    keyIdValueDepositable(target).setObject(depositable, forKey: id!)
    depositable.depositableDidAdd()
    
    objc_sync_exit(target)
    
    return depositable
}

public func getDeposited(from target: AnyObject, #id: String) -> Depositable? {
    objc_sync_enter(target)
    
    var depositable = keyIdValueDepositable(target).objectForKey(id) as? Depositable
    
    objc_sync_exit(target)
    
    return depositable
}

public func removeDeposited(from target: AnyObject, #id: String) {
    objc_sync_enter(target)
    
    keyIdValueDepositable(target).removeObjectForKey(id)
    
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
            
            addDeinitObserver(target: target, id: "_depositable_support_removeNotificationCenterObserver", {
                [weak keyIdValueDepositable] () -> () in
                NSNotificationCenter.defaultCenter().removeObserver(observerContext)
                if let wkeyIdValueDepositable = keyIdValueDepositable {
                    notifyAllDepositables(wkeyIdValueDepositable)
                } else {
                    println("unexpected runtime error: keyIdValueDepositable nil")
                }
            })
        #else
            addDeinitObserver(target: target, id: "_depositable_support_removeNotificationCenterObserver", { () -> () in
                if let wkeyIdValueDepositable = keyIdValueDepositable {
                    notifyAllDepositables(wkeyIdValueDepositable)
                } else {
                    println("unexpected runtime error: keyIdValueDepositable nil")
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
    
    for (key, value) in keyIdValueDepositable {
        var depositable = value as! Depositable
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
