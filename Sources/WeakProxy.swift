//
//  WeakProxy.swift
//  AnimatedImageKit-iOS
//
//  Created by Zhu Shengqi on 12/11/2017.
//

import Foundation

public final class WeakProxy<T: NSObjectProtocol>: NSObject {
  
  private weak var target: T?
  
  init(target: T) {
    self.target = target
    
    super.init()
  }
  
  public override func responds(to aSelector: Selector!) -> Bool {
    return (target?.responds(to: aSelector) ?? false) || super.responds(to: aSelector)
  }
  
  public override func forwardingTarget(for aSelector: Selector!) -> Any? {
    return target
  }
  
}
