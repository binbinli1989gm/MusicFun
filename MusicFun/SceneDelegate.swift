//
//  SceneDelegate.swift
//  MusicFun
//
//  Created by Robert Arvin Lee on 6/3/26.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        print("3. SceneDelegate is running!")
        // 1. Capture the scene
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // 2. Initialize the window with the scene
        let window = UIWindow(windowScene: windowScene)
        
        // 3. Set the Root View Controller
        let firstVC = FirstViewController()
        
        window.rootViewController = UINavigationController(rootViewController: firstVC)
        
        // 4. CRITICAL: Assign to the class property and make visible
        self.window = window
        window.makeKeyAndVisible()
        
        print("SceneDelegate: Window is set!") // Check your console for this!
    }
}
