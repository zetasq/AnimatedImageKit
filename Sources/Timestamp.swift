//
//  TimeStamp.swift
//  AnimatedImageKit-iOS
//
//  Created by Zhu Shengqi on 09/12/2017.
//

import Foundation

// http://www.guyrutenberg.com/2007/09/22/profiling-code-using-clock_gettime/
public struct Timestamp {
  
  private var _spec: timespec
  
  public init() {
    var time = timespec()
    clock_gettime(CLOCK_MONOTONIC, &time)
    _spec = time
  }
  
  public mutating func add(seconds: Int) {
    _spec.tv_sec += seconds
  }
  
  public func nanoseconds(since start: Timestamp) -> Int {
    return (self._spec.tv_sec - start._spec.tv_sec) * 1000 * 1000 * 1000 + (self._spec.tv_nsec - start._spec.tv_nsec)
  }
  
  public func microseconds(since start: Timestamp) -> Int {
    return (self._spec.tv_sec - start._spec.tv_sec) * 1000 * 1000 + (self._spec.tv_nsec - start._spec.tv_nsec) / 1000
  }
  
  public func milliseconds(since start: Timestamp) -> Int {
    return (self._spec.tv_sec - start._spec.tv_sec) * 1000 + (self._spec.tv_nsec - start._spec.tv_nsec) / (1000 * 1000)
  }
  
  public func seconds(since start: Timestamp) -> Int {
    return self._spec.tv_sec - start._spec.tv_sec
  }
}

extension Timestamp: Comparable {
  
  public static func <(lhs: Timestamp, rhs: Timestamp) -> Bool {
    if lhs._spec.tv_sec < rhs._spec.tv_sec {
      return true
    } else if lhs._spec.tv_sec == rhs._spec.tv_sec {
      return lhs._spec.tv_nsec < rhs._spec.tv_nsec
    } else {
      return false
    }
  }
  
  public static func ==(lhs: Timestamp, rhs: Timestamp) -> Bool {
    return lhs._spec.tv_sec == rhs._spec.tv_sec && lhs._spec.tv_nsec == rhs._spec.tv_nsec
  }
  
}

