//
//  MessageQueue.swift
//  AnimatedImageKit-iOS
//
//  Created by Zhu Shengqi on 12/11/2017.
//

import Foundation

public final class MessageQueue: NSObject {
  
  private var _messageItems: [MessageItem] = []
  
  public func enqueueAsyncOperation(identifier: String, delay: TimeInterval, block: @escaping () -> Void) {
    
  }
  
  public func cancelAsyncOperation(identifier: String) {
    
  }
  
}
