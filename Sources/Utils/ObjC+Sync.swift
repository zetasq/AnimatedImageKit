//
//  ObjC+Sync.swift
//  AnimatedImageKit-iOS
//
//  Created by Zhu Shengqi on 19/11/2017.
//

import Foundation

internal func objc_synchronize<T: AnyObject, U>(_ obj: T, block: () throws -> U) rethrows -> U {
  objc_sync_enter(obj)
  defer {
    objc_sync_exit(obj)
  }
  
  return try block()
}
