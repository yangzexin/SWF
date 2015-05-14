//
//  NSObject+DeinitObserver.swift
//  SFLibs
//
//  Created by yangzexin on 5/11/15.
//  Copyright (c) 2015 yangzexin. All rights reserved.
//

import Foundation
import ObjectiveC

public func addDiedObserver(#target: AnyObject, observer: () -> ()) -> String {
    objc_sync_enter(target)
    
    var id = String(stringInterpolationSegment: NSDate.timeIntervalSinceReferenceDate())
    
    objc_sync_exit(target)
    
    return addDiedObserver(target: target, id: id, observer)
}

/**
Observer context is managed by #target through associated object, when #target died, the context will be auto release by #target
*/
public func addDiedObserver(#target: AnyObject, #id: String, observer: () -> ()) -> String {
    diedObservingContext(target).addObserver(id: id, observer: observer)
    
    return id
}

public func removeDiedObserver(#target: AnyObject, #id: String) {
    diedObservingContext(target).removeObserver(id: id)
}

private var DiedObserverContextKey = "DiedObserverContextKey";

private class DiedObservingContext {
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

private func diedObservingContext(target: AnyObject) -> DiedObservingContext {
    var context: DiedObservingContext!
    
    objc_sync_enter(target)
    
    if let existsContext = objc_getAssociatedObject(target, &DiedObserverContextKey) as? DiedObservingContext {
        context = existsContext
    } else {
        context = DiedObservingContext()
        objc_setAssociatedObject(target, &DiedObserverContextKey, context, UInt(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
    }
    
    objc_sync_exit(target)
    
    return context
}
