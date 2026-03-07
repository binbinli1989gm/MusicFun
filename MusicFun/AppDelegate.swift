//
//  AppDelegate.swift
//  MusicFun
//
//  Created by Robert Arvin Lee on 6/3/26.
//

import UIKit

@main // This attribute creates the 'main' symbol the linker is looking for
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("1. AppDelegate started")
        return true
    }

    // This tells iOS to use your SceneDelegate for the UI
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        print("2. AppDelegate handing off to SceneDelegate")
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
