//
//  Call.swift
//  SWFoundation
//
//  Created by yangzexin on 5/11/15.
//  Copyright (c) 2015 yangzexin. All rights reserved.
//

import Foundation

public let CallTimeoutErrorDomain  = "Time out"
public let CallTimeoutErrorCode    = -100001
public let CallNilCallErrorDomain   = "Nil call"
public let CallNilCallErrorCode     = -200001

public protocol Call : Depositable {
    func start(#callback: (out: Out) -> ())
    func isExecuting() -> Bool
    func cancel()
}

public struct Out {
    public var value: Any?
    public var error: NSError?
    
    public init(value: Any) {
        self.value = value
    }
    
    public init(error: NSError) {
        self.error = error
    }
    
    public func hasValue() -> Bool {
        if let err = self.error {
            return false
        }
        
        return true
    }
}

public class BaseCall : Call {
    private var callback: ((out: Out) -> ())?
    private var cancelled: Bool = false
    private var executing: Bool = false
    
    public func start(#callback: (out: Out) -> ()) {
        objc_sync_enter(self)
        
        self.callback = callback
        self.cancelled = false
        self.executing = true
        self.didStart()
        
        objc_sync_exit(self)
    }
    
    public func isExecuting() -> Bool {
        return self.executing
    }
    
    public func cancel() {
        objc_sync_enter(self)
        
        self.executing = false
        self.cancelled = true
        self.callback = nil
        self.didCancel()
        
        objc_sync_exit(self)
    }
    
    public func shouldRemoveDepositable() -> Bool {
        return !self.isExecuting()
    }
    
    public func depositableWillRemove() {
        self.cancel()
    }
    
    public func depositableDidAdd() {
        
    }
    
    public func finish(#out: Out) {
        objc_sync_enter(self)
        
        if !self.cancelled {
            self.didFinish(out)
            if let callback = self.callback {
                callback(out: out)
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self.callback = nil
                })
            }
            self.executing = false
        }
        
        objc_sync_exit(self)
    }
    
    public func didStart() {
    }
    
    public func didCancel() {
    }
    
    public func didFinish(out: Out) {
    }
}

public class ComposableCall : BaseCall {
    private var out: Out
    private var synchronous = false
    
    public init(out: Out) {
        self.out = out
    }
    
    convenience init(out: Out, synchronous: Bool) {
        self.init(out: out)
        self.setSynchronous(synchronous)
    }
    
    public func setSynchronous(synchronous: Bool) -> ComposableCall {
        self.synchronous = synchronous
        
        return self
    }
    
    override public func didStart() {
        if self.synchronous {
            self.finish(out: self.out)
        } else {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.finish(out: self.out)
            })
        }
    }
}

public class WrappedCall : BaseCall {
    private var call: Call?
    
    private override init() {}
    
    public init(_ call: Call) {
        self.call = call
    }
    
    override public func didStart() {
        super.didStart()
        
        if let call = self.call {
            call.start(callback: { [weak self] (out) -> () in
                self?.finish(out: out)
            })
        }
    }
    
    override public func isExecuting() -> Bool {
        if let call = self.call {
            return call.isExecuting()
        }
        
        return false
    }
    
    override public func cancel() {
        if let call = self.call {
            call.cancel()
        }
    }
    
    public override func shouldRemoveDepositable() -> Bool {
        if let call = self.call {
            return call.shouldRemoveDepositable()
        }
        
        return true
    }
    
    public override func depositableWillRemove() {
        if let call = self.call {
            call.depositableWillRemove()
        }
    }
    
    public override func depositableDidAdd() {
        if let call = self.call {
            call.depositableDidAdd()
        }
    }
    
    public func wrapOut(outWrapper: (out: Out) -> Out) -> WrappedCall {
        var call = OutWrapCall(self, outWrapper: outWrapper)
        
        return call
    }
    
    public func sync() -> WrappedCall {
        var call = SyncedCall(self)
        
        return call
    }
    
    public func intercept(#callback: (out: Out) -> ()) -> WrappedCall {
        var call = MulticastCall(self, multicastCallback: callback)
        
        return call
    }
    
    public func once() -> WrappedCall {
        var call = OnceCall(self)
        
        return call
    }
    
    public func mainthreadCallback() -> WrappedCall {
        var call = MainThreadCallbackCall(self)
        
        return call
    }
    
    public func timeout(timeoutInSeconds: Double) -> WrappedCall {
        var call = TimeoutCall(self, timeoutInterval: timeoutInSeconds)
        
        return call
    }
    
    public func append(continuing: (out: Out) -> Call) -> WrappedCall {
        var call = SequenceCall(call: self, continuing: continuing)
        
        return call
    }
    
    public func deposit(#by: AnyObject, id: String? = nil) -> WrappedCall {
        return _deposit(to: by, with: self, id: id)
    }
}

private class OutWrapCall : WrappedCall {
    private var outWrapper: (out: Out) -> Out
    
    init(_ call: Call, outWrapper: (out: Out) -> Out) {
        self.outWrapper = outWrapper
        super.init(call)
    }
    
    override private func didStart() {
        if let call = self.call {
            call.start(callback: { [weak self] (out) -> () in
                if let wself = self {
                    let wrappedOut = wself.outWrapper(out: out)
                    wself.finish(out: wrappedOut)
                }
            })
        }
    }
}

private class MulticastCall : WrappedCall {
    private var multicastCallback: ((out: Out) -> ())
    
    init(_ call: Call, multicastCallback:((out: Out) -> ())) {
        self.multicastCallback = multicastCallback
        super.init(call)
    }
    
    override private func didStart() {
        if let call = self.call {
            call.start(callback: { [weak self] (out) -> () in
                self?.multicastCallback(out: out)
                self?.finish(out: out)
            })
        }
    }
}

private class MainThreadCallbackCall : WrappedCall {
    override private func didStart() {
        if let call = self.call {
            call.start(callback: { [weak self] (out) -> () in
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self?.finish(out: out)
                })
            })
        }
    }
}

private class TimeoutCall : WrappedCall {
    private var timeoutInterval: Double
    private var finished = false
    
    init(_ call: Call, timeoutInterval: Double) {
        self.timeoutInterval = timeoutInterval
        super.init(call)
    }
    
    override private func didStart() {
        var call = self.call!
        
        self.finished = false
        
        call.start { [weak self] (out) -> () in
            self?.finished = true
            self?.finish(out: out)
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(self.timeoutInterval * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            [weak self] () -> Void in
            if let wself = self {
                if !wself.finished {
                    wself.call?.cancel()
                    wself.finish(out: Out(error: wself.error()))
                }
            }
        }
    }
    
    private func error() -> NSError {
        return NSError(domain: CallTimeoutErrorDomain, code: CallTimeoutErrorCode, userInfo: [NSLocalizedDescriptionKey : "Call time out"])
    }
}

private class SyncedCall : WrappedCall {
    var out: Out?
    
    override private func didStart() {
        assert(!NSThread.isMainThread(), "SyncedCall shouldn't be running in mainthread")
        var sema = dispatch_semaphore_create(0)
        
        var call = self.call!
        call.start { [weak self] (out) -> () in
            self?.out = out
            dispatch_semaphore_signal(sema)
        }
        
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER)
        
        self.finish(out: self.out!)
    }
}

private class SequenceCall : WrappedCall {
    private var continuing: ((out: Out) -> Call)
    private var continuingCall: Call?
    
    init(call: Call, continuing: ((out: Out) -> Call)) {
        self.continuing = continuing
        super.init(call)
    }
    
    override private func didStart() {
        self.call!.start { [weak self] (out) -> () in
            self?.originalCallDidFinish(out)
        }
    }
    
    override func cancel() {
        super.cancel()
        self.continuingCall?.cancel()
    }
    
    private func originalCallDidFinish(out: Out) {
        if !self.cancelled {
            self.continuingCall = self.continuing(out: out)
            self.continuingCall?.start(callback: { [weak self] (out) -> () in
                self?.finish(out: out)
            })
        }
    }
}

private class OnceCall : WrappedCall {
    private var called = false
    
    override private func start(#callback: (out: Out) -> ()) {
        objc_sync_enter(self)
        
        if !self.called {
            self.called = true
            
            super.start(callback: callback)
        }
        
        objc_sync_exit(self)
    }
}

private class GroupCall : WrappedCall {
    private var keyIdValueCall: Dictionary<String, Call>
    private var keyIdValueOut: Dictionary<String, Out>?
    private var processingIdentifiers: Array<String>?
    
    init(keyIdValueCall: Dictionary<String, Call>) {
        self.keyIdValueCall = keyIdValueCall
        super.init()
    }
    
    override func didStart() {
        super.didStart()
        self.keyIdValueOut = Dictionary<String, Out>()
        self.processingIdentifiers = Array<String>(self.keyIdValueCall.keys)
        
        let allIdentifiers = self.processingIdentifiers!
        for identifier in allIdentifiers {
            var singleCall = self.keyIdValueCall[identifier]!
            singleCall.start(callback: { [weak self] (out) -> () in
                if let wself = self {
                    if !wself.cancelled {
                        wself.keyIdValueOut!.updateValue(out, forKey: identifier)
                        wself.processingIdentifiers!.removeAtIndex((find(wself.processingIdentifiers!, identifier))!)
                        if wself.processingIdentifiers!.count == 0 {
                            wself.finish(out: Out(value: wself.keyIdValueOut!))
                        }
                    }
                }
            })
        }
    }
}

public func group(#keyIdValueCall: Dictionary<String, Call>) -> WrappedCall {
    var call = GroupCall(keyIdValueCall: keyIdValueCall)
    
    return call
}
