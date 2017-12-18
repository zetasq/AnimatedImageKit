//
//  SampleTests.swift
//  AnimatedImageKit-iOS
//
//  Created by Zhu Shengqi on 12/11/2017.
//

import XCTest
@testable import AnimatedImageKit

class SampleTests: XCTestCase {
  
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
      let a = Timestamp()
      sleep(2)
      let b = Timestamp()
      print(b.nanoseconds(since: a))
    }
}

