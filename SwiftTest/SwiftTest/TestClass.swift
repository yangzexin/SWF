//
//  TestClass.swift
//  SwiftTest
//
//  Created by yangzexin on 4/30/15.
//  Copyright (c) 2015 yangzexin. All rights reserved.
//

import UIKit

var tc:TestClass = TestClass() {
    willSet {
        println("willSet")
    }
    didSet {
        println("didSet")
    }
}

class TestClass: NSObject {
    var testValue: Int = 10
    class var testTypeValue: Int {
        return 10;
    }
}

class TClass : TestClass {
    
    deinit {
        println("deinit\(self.testValue)")
    }
}
