//
//  PlayheadView.swift
//  iOSDemo
//
//  Created by Zhu Shengqi on 02/12/2017.
//

import UIKit

final class PlayheadView: UIView {
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    self.isOpaque = false
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func draw(_ rect: CGRect) {
    let path = UIBezierPath()
    
    path.move(to: rect.origin)
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.origin.y))
    path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
    path.close()
    UIColor(white: 0.8, alpha: 1).setFill()
    path.fill()
  }
  
}
