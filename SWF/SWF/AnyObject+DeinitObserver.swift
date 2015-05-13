//
//  NSObject+DeinitObserver.swift
//  SFLibs
//
//  Created by yangzexin on 5/11/15.
//  Copyright (c) 2015 yangzexin. All rights reserved.
//

import Foundation
import ObjectiveC

private var DeinitObserverContextKey = "DeinitObserverContextKey";

private class DeinitObservingContext {
    private var keyIdValueObserver: Dictionary<String, Any> = Dictionary()
    
    deinit {
        for value in self.keyIdValueObserver.values {
            let observer = value as! () -> ()
            observer()
        }
    }
    
    private func addObserver(#id: String, observer: () -> ()) {
        keyIdValueObserver.updateValue(observer, forKey: id)
    }
    
    private func removeObserver(#id: String) {
        keyIdValueObserver.removeValueForKey(id)
    }
}

private func deinitObservingContext(target: AnyObject) -> DeinitObservingContext {
    var context: DeinitObservingContext!
    
    objc_sync_enter(target)
    
    if let existsContext = objc_getAssociatedObject(target, &DeinitObserverContextKey) as? DeinitObservingContext {
        context = existsContext
    } else {
        context = DeinitObservingContext()
        objc_setAssociatedObject(target, &DeinitObserverContextKey, context, UInt(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
    }
    
    objc_sync_exit(target)
    
    return context
}

public func addDeinitObserver(#target: AnyObject, #id: String, observer: () -> ()) {
    deinitObservingContext(target).addObserver(id: id, observer: observer)
}

public func removeDeinitObserver(#target: AnyObject, #id: String) {
    deinitObservingContext(target).removeObserver(id: id)
}
