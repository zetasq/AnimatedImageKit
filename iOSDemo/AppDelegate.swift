//
//  AppDelegate.swift
//  iOSDemo
//
//  Created by Zhu Shengqi on 26/11/2017.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  
  var window: UIWindow?
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    
    let mainWindow = UIWindow()
    self.window = mainWindow
    
    mainWindow.rootViewController = UINavigationController(rootViewController: RootViewController())
    mainWindow.makeKeyAndVisible()
    
    return true
  }
  
}

