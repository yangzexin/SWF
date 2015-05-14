//
//  Depositable.swift
//  SWF
//
//  Created by yangzexin on 5/11/15.
//  Copyright (c) 2015 yangzexin. All rights reserved.
//

import Foundation

public protocol Depositable : AnyObject {
    func shouldRemoveDepositable() -> Bool
    func depositableWillRemove()
    func depositableDidAdd()
}
