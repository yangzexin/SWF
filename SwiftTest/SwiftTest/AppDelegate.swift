//
//  AppDelegate.swift
//  SwiftTest
//
//  Created by yangzexin on 4/30/15.
//  Copyright (c) 2015 yangzexin. All rights reserved.
//

import UIKit
import SWF

@UIApplicationMain

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
//        var shoppingList = ["Eggs", "Milk"]
//        shoppingList.append("Flour")
//        shoppingList += ["Baking Powder"]
//        shoppingList += ["Chocolate Spread", "Cheese", "Butter"]
//        shoppingList[0] = "Six eggs";
//        
//        shoppingList[4...6] = ["Bananas", "Apples"]
//        
//        let anotherPoint = (0, 2)
//        switch anotherPoint {
//        case (let x, 0):
//            println("on the x-axis with an x value of \(x)")
//        case (0, let y):
//            println("on the y-axis with an y value of \(y)")
//            if y == 2 {
//                break
//            }
//            println("aaa on the y-axis with an y value of \(y)")
//        case let (x, y):
//            println("somewhere else at (\(x), \(y))")
//        }
//        
//        tupleOptionalReturnValues(localParam: 1);
//        
//        tc = TestClass()
//        println(tc.testValue)
//        
//        var tcc = TClass()
//        tcc.testValue = 19
//        
//        var tcc2 = TClass()
//        tcc2.testValue = 22
//        tcc.setAssociatedObject(key: "test", object: tcc2)
//        
//        println(tcc.getAssociatedObject(key: "test"))
//        tcc.removeAssociatedObject(key: "test")
//        
//        tcc2.addDeinitObserver(identifier: "testobserver") { () -> () in
//            println("tcc2 deinit")
//        }
//        tcc2.removeDeinitObserver(identifier: "testobserver")
//        
//        var dict = "est";
//        dict.addDeinitObserver(identifier: "test") { () -> () in
//            println("str deinit")
//        }
//        
//        var cll: BaseCall()
//        cll.finish(result: "str", error: nil)
//        
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(2 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
//            println("2")
//            tcc.testValue = 20
//        }
        
        var c1 = ComposableCall(out: Out(value: "test"))
        c1.setSynchronous(true)
        
        var gc = WrappedCall(c1).append { (result) -> Call in
            var str = "original:"
            if result.hasValue() {
                str += result.value as! String
            }
            
            return ComposableCall(out: Out(value: str))
        }.append { (result) -> Call in
            var str = "prefix:"
            if result.hasValue() {
                str += result.value as! String
            }
            
            return ComposableCall(out: Out(value: str))
        }.once().timeout(1).sync().mainthreadCallback().intercept { (result) -> () in
            if result.hasValue() {
                println(result.value!)
            } else {
                println(result.error!)
            }
        }
        gc = WrappedCall(gc).wrapOut { (result) -> Out in
            return Out(value: "wappedResult")
        }.intercept { (result) -> () in
            if result.hasValue() {
                println(result.value!)
            } else {
                println(result.error!)
            }
        }
        
        addDiedObserver(target: gc) { () -> () in
            println("gc died")
        }
        
        var str = ComposableCall(out: Out(value: "str"))
        
        deposit(to:self, with: str, id: "teststr")
        
        after(5, { () -> () in
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { () -> Void in
                gc.deposit(by: self).start { (result) -> () in
                    if result.hasValue() {
                        println(result.value!)
                    } else {
                        println(result.error!)
                    }
                }
                
                println("sync")
            })
        })
        
        var af = after(10, { () -> () in
            removeDeposited(from: self, id: "teststr")
            removeDeposited(from: self, id: "test")
        })
        
        return true
    }
    
    func tupleOptionalReturnValues(localParam: Int = 2) -> (min: Int, max: Int?) {
        return (1, nil)
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

