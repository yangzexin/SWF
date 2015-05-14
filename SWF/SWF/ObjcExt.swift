//
//  ObjcExt.swift
//  SWF
//
//  Created by yangzexin on 5/14/15.
//  Copyright (c) 2015 yangzexin. All rights reserved.
//

import Foundation

public func objc_sync(target: AnyObject, block: () -> ()) {
    objc_sync_enter(target)
    
    block()
    
    objc_sync_exit(target)
}

public func after(seconds: Double, block: (() -> ())) -> Depositable {
    return Delay(seconds: seconds, trigger: block).start() as Depositable
}

private class Delay : NSObject, Depositable {
    let seconds: Double
    var finished = false
    var trigger: (() -> ())?
    var started = false
    
    var invokingThread: NSThread
    
    init(seconds: Double, trigger: () -> ()) {
        self.seconds = seconds
        self.trigger = trigger
        self.invokingThread = NSThread.currentThread()
    }
    
    func shouldRemoveDepositable() -> Bool {
        return self.finished
    }
    
    func depositableWillRemove() {
        self.trigger = nil
    }
    
    func start() -> Delay {
        if !self.started {
            self.started = true
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(self.seconds * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
                if let trigger = self.trigger {
                    trigger()
                }
                self.finished = true
            }
        }
        
        return self
    }
    
    func depositableDidAdd() {
        
    }
}