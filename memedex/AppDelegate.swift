//
//  AppDelegate.swift
//  memedex
//
//  Created by meagh054 on 2/12/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import CoreData
import AWSCognito
import AWSCognitoIdentityProvider
import AWSCore
import AWSS3
import AWSDynamoDB


let userPoolID = "SampleUserPool"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    
    var navigationController: UINavigationController?
    var viewController: UIViewController?
    var loginViewController: LoginViewController?
    static var pool: AWSCognitoIdentityUserPool?
    
    var storyboard: UIStoryboard? {
        print("here2")
        return UIStoryboard(name: "Main", bundle: nil)
    }
    
    class func defaultUserPool() -> AWSCognitoIdentityUserPool {
        print("here1")
        return AWSCognitoIdentityUserPool(forKey: userPoolID)
    }

    var window: UIWindow?
    
    var cognitoConfig:CognitoConfig?
    
    /*class func checkLogin () -> UIViewController {
        /*if (self.navigationController == nil){
            
        }
        if (self.viewController == nil){
            
        }*/
        return loginView()
    }*/
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("In App Delegate1")
    //navigationController?.view.backgroundColor = UIColor.clear
        //self.window?.tintColor = UIColor.white
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.USEast2,
        identityPoolId:"us-east-2:7ddd079c-2a06-460d-975c-7fbf8c32c4d8")
        
        // Change back to USWest1
        let configuration = AWSServiceConfiguration(region:.USWest1, credentialsProvider:credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        AWSS3.register(with: configuration!, forKey: "defaultKey")
        AWSDDLog.sharedInstance.logLevel = .verbose
        AWSDDLog.add(AWSDDTTYLogger.sharedInstance)
        self.cognitoConfig = CognitoConfig()
        setupCognitoUserPool()
        
        
        
        // Override point for customization after application launch.

        //let syncClient = AWSCognito.default()
        
        return true
    }
    
    func setupCognitoUserPool() {
        print("here4")
        let clientId:String = self.cognitoConfig!.getClientId()
        let poolId:String = self.cognitoConfig!.getPoolId()
        let clientSecret:String = self.cognitoConfig!.getClientSecret()
        let region:AWSRegionType = self.cognitoConfig!.getRegion()
        
        let serviceConfiguration:AWSServiceConfiguration = AWSServiceConfiguration(region: region, credentialsProvider: nil)
        let cognitoConfiguration:AWSCognitoIdentityUserPoolConfiguration = AWSCognitoIdentityUserPoolConfiguration(clientId: clientId, clientSecret: clientSecret, poolId: poolId)
        AWSCognitoIdentityUserPool.register(with: serviceConfiguration, userPoolConfiguration: cognitoConfiguration, forKey: userPoolID)
        AppDelegate.pool = AppDelegate.defaultUserPool()
        AppDelegate.pool!.delegate = self
    }

    // MARK: - Core Data stack

    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "memedex")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                 
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

}

extension AppDelegate: AWSCognitoIdentityInteractiveAuthenticationDelegate {
    
    func startPasswordAuthentication() -> AWSCognitoIdentityPasswordAuthentication {
        print("here5")
        if(self.navigationController == nil) {
            print("here5.1")
            self.navigationController = self.window?.rootViewController as? UINavigationController
        }
        
        if(self.loginViewController == nil) {
            print("here5.2")
            self.loginViewController = self.storyboard?.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController
            self.loginViewController?.isModalInPresentation = true
        }
        
        DispatchQueue.main.async {
            print("here5.3")
            if(self.loginViewController!.isViewLoaded || self.loginViewController!.view.window == nil) {
                self.navigationController?.present(self.loginViewController!, animated: true, completion: nil)
            }
        }
        
        return self.loginViewController!
    }
    
}

