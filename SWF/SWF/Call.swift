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
    func start(#callback: (result: Result) -> ())
    func isExecuting() -> Bool
    func cancel()
}

public struct Result {
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
    private var callback: ((result: Result) -> ())?
    private var cancelled: Bool = false
    private var executing: Bool = false
    
    public func start(#callback: (result: Result) -> ()) {
        objc_sync_enter(self)
        
        self.callback = callback
        self.cancelled = false
        self.executing = true
        self.didStart()
        
        objc_sync_exit(self)
    }
    
    public func isExecuting() -> Bool {
        return !self.executing
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
    
    public func finish(#result: Result) {
        objc_sync_enter(self)
        
        if !self.cancelled {
            self.didFinish(result)
            if let callback = self.callback {
                callback(result: result)
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
    
    public func didFinish(result: Result) {
    }
}

public class ComposableCall : BaseCall {
    private var result: Result
    private var synchronous = false
    
    public init(result: Result) {
        self.result = result
    }
    
    convenience init(result: Result, synchronous: Bool) {
        self.init(result: result)
        self.setSynchronous(synchronous)
    }
    
    public func setSynchronous(synchronous: Bool) -> ComposableCall {
        self.synchronous = synchronous
        
        return self
    }
    
    override public func didStart() {
        if self.synchronous {
            self.finish(result: self.result)
        } else {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                self.finish(result: self.result)
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
            call.start(callback: { [weak self] (result) -> () in
                self?.finish(result: result)
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
    
    public func wrapResult(resultWrapper: (result: Result) -> Result) -> WrappedCall {
        var call = ResultWrapCall(self, resultWrapper: resultWrapper)
        
        return call
    }
    
    public func sync() -> WrappedCall {
        var call = SyncedCall(self)
        
        return call
    }
    
    public func intercept(#callback: (result: Result) -> ()) -> WrappedCall {
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
    
    public func append(continuing: (result: Result) -> Call) -> WrappedCall {
        var call = SequenceCall(call: self, continuing: continuing)
        
        return call
    }
    
    public func keep(by: AnyObject, id: String? = nil) -> WrappedCall {
        return deposit(to: by, with: self, id: id)
    }
}

private class ResultWrapCall : WrappedCall {
    private var resultWrapper: (result: Result) -> Result
    
    init(_ call: Call, resultWrapper: (result: Result) -> Result) {
        self.resultWrapper = resultWrapper
        super.init(call)
    }
    
    override private func didStart() {
        if let call = self.call {
            call.start(callback: { [weak self] (result) -> () in
                if let wself = self {
                    let wrappedResult = wself.resultWrapper(result: result)
                    wself.finish(result: wrappedResult)
                }
            })
        }
    }
}

private class MulticastCall : WrappedCall {
    private var multicastCallback: ((result: Result) -> ())
    
    init(_ call: Call, multicastCallback:((result: Result) -> ())) {
        self.multicastCallback = multicastCallback
        super.init(call)
    }
    
    override private func didStart() {
        if let call = self.call {
            call.start(callback: { [weak self] (result) -> () in
                self?.multicastCallback(result: result)
                self?.finish(result: result)
            })
        }
    }
}

private class MainThreadCallbackCall : WrappedCall {
    override private func didStart() {
        if let call = self.call {
            call.start(callback: { [weak self] (result) -> () in
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    self?.finish(result: result)
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
        
        call.start { [weak self] (result) -> () in
            self?.finished = true
            self?.finish(result: result)
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(self.timeoutInterval * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            [weak self] () -> Void in
            if let wself = self {
                if !wself.finished {
                    wself.call?.cancel()
                    wself.finish(result: Result(error: wself.error()))
                }
            }
        }
    }
    
    private func error() -> NSError {
        return NSError(domain: CallTimeoutErrorDomain, code: CallTimeoutErrorCode, userInfo: [NSLocalizedDescriptionKey : "Call time out"])
    }
}

private class SyncedCall : WrappedCall {
    var result: Result?
    
    override private func didStart() {
        assert(!NSThread.isMainThread(), "SyncedCall shouldn't be running in mainthread")
        var sema = dispatch_semaphore_create(0)
        
        var call = self.call!
        call.start { [weak self] (result) -> () in
            self?.result = result
            dispatch_semaphore_signal(sema)
        }
        
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER)
        
        self.finish(result: self.result!)
    }
}

private class SequenceCall : WrappedCall {
    private var continuing: ((result: Result) -> Call)
    private var continuingCall: Call?
    
    init(call: Call, continuing: ((result: Result) -> Call)) {
        self.continuing = continuing
        super.init(call)
    }
    
    override private func didStart() {
        self.call!.start { [weak self] (result) -> () in
            self?.originalCallDidFinish(result)
        }
    }
    
    override func cancel() {
        super.cancel()
        self.continuingCall?.cancel()
    }
    
    private func originalCallDidFinish(result: Result) {
        if !self.cancelled {
            self.continuingCall = self.continuing(result: result)
            self.continuingCall?.start(callback: { [weak self] (result) -> () in
                self?.finish(result: result)
            })
        }
    }
}

private class OnceCall : WrappedCall {
    private var called = false
    
    override private func start(#callback: (result: Result) -> ()) {
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
    private var keyIdValueResult: Dictionary<String, Result>?
    private var processingIdentifiers: Array<String>?
    
    init(keyIdValueCall: Dictionary<String, Call>) {
        self.keyIdValueCall = keyIdValueCall
        super.init()
    }
    
    override func didStart() {
        super.didStart()
        self.keyIdValueResult = Dictionary<String, Result>()
        self.processingIdentifiers = Array<String>(self.keyIdValueCall.keys)
        
        let allIdentifiers = self.processingIdentifiers!
        for identifier in allIdentifiers {
            var singleCall = self.keyIdValueCall[identifier]!
            singleCall.start(callback: { [weak self] (result) -> () in
                if let wself = self {
                    if !wself.cancelled {
                        wself.keyIdValueResult!.updateValue(result, forKey: identifier)
                        wself.processingIdentifiers!.removeAtIndex((find(wself.processingIdentifiers!, identifier))!)
                        if wself.processingIdentifiers!.count == 0 {
                            wself.finish(result: Result(value: wself.keyIdValueResult!))
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
