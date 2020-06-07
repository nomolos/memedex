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
import AWSMobileClient
import AWSPinpoint
import Amplify
import AmplifyPlugins


let userPoolID = "SampleUserPool"
var pinpoint: AWSPinpoint?

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    
    var navigationController: UINavigationController?
    var viewController: UIViewController?
    var loginViewController: LoginViewController?
    var verificationViewController: VerificationViewController?
    var goldenSetViewController: GoldenSetViewController?
    static var pool: AWSCognitoIdentityUserPool?
    static var loggedIn: Bool?
    
    var storyboard: UIStoryboard? {
        return UIStoryboard(name: "Main", bundle: nil)
    }
    
    class func defaultUserPool() -> AWSCognitoIdentityUserPool {
        return AWSCognitoIdentityUserPool(forKey: userPoolID)
    }
    
    var window: UIWindow?
    
    var cognitoConfig:CognitoConfig?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppDelegate.loggedIn = false
        
        // Initialize Pinpoint
        pinpoint = AWSPinpoint(configuration:
                AWSPinpointConfiguration.defaultPinpointConfiguration(launchOptions: launchOptions))
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.USEast2,
        identityPoolId:"us-east-2:7ddd079c-2a06-460d-975c-7fbf8c32c4d8")
        
        // Can add logger (commented out)
        // For more info
        let configuration = AWSServiceConfiguration(region:.USWest1, credentialsProvider:credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        AWSS3.register(with: configuration!, forKey: "defaultKey")
        //AWSDDLog.sharedInstance.logLevel = .verbose
        //AWSDDLog.add(AWSDDTTYLogger.sharedInstance)
        self.cognitoConfig = CognitoConfig()
        self.setupCognitoUserPool()
        do {
            try Amplify.add(plugin: AWSPinpointAnalyticsPlugin())
            try Amplify.configure()
            print("Amplify configured with analytics plugin")
        } catch {
            print("Failed to initialize Amplify with \(error)")
        }
        // Override point for customization after application launch.
        return AWSMobileClient.sharedInstance().interceptApplication(
            application,
            didFinishLaunchingWithOptions: launchOptions)
    }
    
    /*
    State restoration stuff
    Haven't gotten it to work yet
    
    func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
        print("shouldsavesecureappstate")
        self.viewController?.encodeRestorableState(with: NSCoder())
        return true
    }
    
    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        return true
    }
    
    func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
        print("shouldrestoresecureappstate")
        return true
    }*/
    
    func setupCognitoUserPool() {
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

// This will be triggered when
// 1. Set up cognito pool
// 2. Log in
// 3. Log out
extension AppDelegate: AWSCognitoIdentityInteractiveAuthenticationDelegate {
    func startPasswordAuthentication() -> AWSCognitoIdentityPasswordAuthentication {
        if(AppDelegate.loggedIn!){
            self.navigationController?.setViewControllers([self.loginViewController!], animated: true)
        }
        else if (self.navigationController == nil) {
            self.navigationController = self.window?.rootViewController as? UINavigationController
        }
        else{
            print("No conditions satisified AppDelegate")
        }
        return self.loginViewController!
    }
}

