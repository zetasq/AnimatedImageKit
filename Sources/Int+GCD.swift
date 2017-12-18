//
//  Int+GCD.swift
//  AnimatedImageKit-iOS
//
//  Created by Zhu Shengqi on 25/11/2017.
//

import Foundation

internal func GCD(_ a: Int, _ b: Int) -> Int {
  guard a >= b else {
    return GCD(b, a)
  }
  
  guard a != b else {
    return a
  }
  
  var a = a
  var b = b
  
  while true {
    let remainder = a % b
    if remainder == 0 {
      return b
    }
    a = b
    b = remainder
  }
}
