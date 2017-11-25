//
//  NSRecursiveLock+Sync.swift
//  AnimatedImageKit-iOS
//
//  Created by Zhu Shengqi on 19/11/2017.
//

import Foundation

extension NSRecursiveLock {
  
  internal func sync<T>(_ block: () -> T) -> T {
    self.lock()
    defer {
      self.unlock()
    }
    
    return block()
  }
  
}
