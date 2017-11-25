//
//  WeakProxy.swift
//  AnimatedImageKit-iOS
//
//  Created by Zhu Shengqi on 12/11/2017.
//

import Foundation

internal class WeakProxy<T: NSObject>: NSObject {
  
  private weak var target: T?
  
  init(target: T) {
    self.target = target
    
    super.init()
  }
  
  override func responds(to aSelector: Selector!) -> Bool {
    return (target?.responds(to: aSelector) ?? false) || super.responds(to: aSelector)
  }
  
  override func forwardingTarget(for aSelector: Selector!) -> Any? {
    return target
  }
  
}
