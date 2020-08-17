//
//  SceneDelegate.swift
//  memedex
//
//  Created by meagh054 on 6/7/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import FBSDKCoreKit

@available(iOS 13.0, *)
@objc
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    var navigationController: UINavigationController?
    var viewController: ViewController?
    var loginViewController: LoginViewController?
    
        /** Applications should configure their UIWindow, and attach the UIWindow to the provided UIWindowScene scene.
     
            If using a storyboard file (as specified by the Info.plist key, UISceneStoryboardFile,
            the window property will automatically be configured and attached to the windowScene.
     
            Remember to retain the SceneDelegate 's UIWindow.
            The recommended approach is for the SceneDelegate to retain the scene's window.
        */
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
            // Do we have an activity to restore?
            if let userActivity = connectionOptions.userActivities.first ?? session.stateRestorationActivity {
                // Setup the view controller with it's restoration activity.
                self.navigationController = self.window?.rootViewController as! UINavigationController
                self.loginViewController = self.navigationController?.viewControllers[0] as! LoginViewController
                if !configure(window: window, with: userActivity) {
                    print("Failed to restore DetailViewController from \(userActivity)")
                }
                return
            }
            guard let windowScene = (scene as? UIWindowScene) else { return }
            self.window = UIWindow(windowScene: windowScene)
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let rootVC = storyboard.instantiateViewController(identifier: "LoginViewController") as? LoginViewController else {
                print("LoginViewController not found")
                return
            }
            let rootNC = UINavigationController(rootViewController: rootVC)
            self.navigationController = rootNC
            self.window?.rootViewController = rootNC
            var login_view = rootVC as? LoginViewController
            self.loginViewController = login_view
            self.window?.makeKeyAndVisible()
        }
        
    func configure(window: UIWindow?, with activity: NSUserActivity) -> Bool {
            print("func configure SceneDelegate")
        if let viewController = ViewController.loadFromStoryboard() {
                if let navigationController = window?.rootViewController as? UINavigationController {
                    navigationController.pushViewController(viewController, animated: false)
                    viewController.restoreUserActivityState(activity)
                    return true
                }
            }
            return false
        }
        
        /** Called as the scene is being released by the system or on window close.
            This occurs shortly after the scene enters the background, or when its session is discarded.
            Release any resources associated with this scene that can be re-created the next time the scene connects.
            The scene may re-connect later, as its session was not neccessarily discarded (see`application:didDiscardSceneSessions` instead).
        */
    func sceneDidDisconnect(_ scene: UIScene) {
            print("sceneDidDisconnect SceneDelegate")
            //..
        }
        
        /** Called as the scene transitions from the background to the foreground,
            on window open or in iOS resume.
            Use this method to undo the changes made on entering the background.
        */
    func sceneWillEnterForeground(_ scene: UIScene) {
            print("sceneWillEnterForeground SceneDelegate")
            //..
        }
        
        /** Called as the scene transitions from the foreground to the background.
            Use this method to save data, release shared resources, and store enough scene-specific state information
            to restore the scene back to its current state.
         */
    func sceneDidEnterBackground(_ scene: UIScene) {
        print("sceneDidEnterBackground SceneDelegate")
    }
        
        /** Called when the scene "will move" from an active state to an inactive state,
            on window close or in iOS enter background.
            This may occur due to temporary interruptions (ex. an incoming phone call).
        */
    /// - Tag: sceneWillResignActive
    func sceneWillResignActive(_ scene: UIScene) {
            print("sceneWillResignActive SceneDelegate")
            if let navController = window!.rootViewController as? UINavigationController {
                if let viewController = navController.viewControllers.last as? ViewController {
                    scene.userActivity = viewController.detailUserActivity
                    //scene.userActivity?.delegate = viewController as! NSUserActivityDelegate
                }
            }
        }
        
        /** Called when the scene "has moved" from an inactive state to an active state.
            Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
            Is called every time a scene becomes active, so setup your scene UI here.
        */
    func sceneDidBecomeActive(_ scene: UIScene) {
            print("sceneDidBecomeActive SceneDelegate")
            //..
        }
        
    // MARK: State Restoration

        // This is the NSUserActivity that will be used to restore state when the scene reconnects.
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
            print("sceneRestorationActivity SceneDelegate")
            return scene.userActivity
        }
    
    // from FB
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            return
        }
        ApplicationDelegate.shared.application(
            UIApplication.shared,
            open: url,
            sourceApplication: nil,
            annotation: [UIApplication.OpenURLOptionsKey.annotation]
        )
    }
    
}
