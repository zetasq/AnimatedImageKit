//
//  ViewController.swift
//  iOSDemo
//
//  Created by Zhu Shengqi on 26/11/2017.
//

import UIKit
import AnimatedImageKit

class RootViewController: UIViewController {
  
  private lazy var triggerMemoryWarningButtonItem: UIBarButtonItem = {
    let triggerMemoryWarningButtonItem = UIBarButtonItem(title: "Memory", style: .plain, target: nil, action: Selector(("_performMemoryWarning")))
    
    triggerMemoryWarningButtonItem.tintColor = UIColor(red: 0.8, green: 0.15, blue: 0.15, alpha: 1)
    
    return triggerMemoryWarningButtonItem
  }()
  
  private lazy var canvasView: UIStackView = {
    let canvasView = UIStackView()
    
    canvasView.axis = .vertical
    canvasView.alignment = .fill
    canvasView.spacing = 10
    canvasView.distribution = .fillEqually
    
    return canvasView
  }()
  
  private lazy var imageView1: AnimatedImageView = {
    let imageView1 = AnimatedImageView()
    
    imageView1.contentMode = .scaleAspectFill
    imageView1.clipsToBounds = true
    imageView1.isUserInteractionEnabled = true
    
    let animatedImage1 = AnimatedImage(fileName: "rock", bundle: .main, frameCachePolicy: .limited(count: 5))!
    imageView1.animatedImage = animatedImage1
    
    let debugView1 = DebugView(style: .default)
    imageView1.debugDelegate = debugView1
    animatedImage1.debugDelegate = debugView1
    debugView1.animatedImageView = imageView1
    debugView1.animatedImage = animatedImage1
    
    imageView1.addSubview(debugView1)
    debugView1.translatesAutoresizingMaskIntoConstraints = false
    debugView1.topAnchor.constraint(equalTo: imageView1.topAnchor).isActive = true
    debugView1.leftAnchor.constraint(equalTo: imageView1.leftAnchor).isActive = true
    debugView1.bottomAnchor.constraint(equalTo: imageView1.bottomAnchor).isActive = true
    debugView1.rightAnchor.constraint(equalTo: imageView1.rightAnchor).isActive = true
    
    
    return imageView1
  }()
  
  private lazy var bottomStackView: UIStackView = {
    let bottomStackView = UIStackView()
    
    bottomStackView.axis = .horizontal
    bottomStackView.alignment = .fill
    bottomStackView.spacing = 10
    bottomStackView.distribution = .fillEqually
    
    return bottomStackView
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupUI()
  }
  
  private func setupUI() {
    title = "AnimatedImageKit"
    view.backgroundColor = UIColor(white: 0.95, alpha: 1)
    
    navigationItem.rightBarButtonItem = triggerMemoryWarningButtonItem
    

    view.addSubview(canvasView)
   
    canvasView.translatesAutoresizingMaskIntoConstraints = false
    canvasView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
    canvasView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
    canvasView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    canvasView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    
    canvasView.addArrangedSubview(imageView1)
  }
  
  
}

