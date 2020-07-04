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
import FBSDKCoreKit
import AWSPluginsCore


let userPoolID = "SampleUserPool"
var pinpoint: AWSPinpoint?

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    
    //var navigationController: UINavigationController?
    var viewController: UIViewController?
    var loginViewController: LoginViewController?
    var verificationViewController: VerificationViewController?
    var goldenSetViewController: GoldenSetViewController?
    static var pool: AWSCognitoIdentityUserPool?
    static var loggedIn: Bool?
    static var fbLoggedIn: Bool?
    static var waitFBUser = DispatchGroup()
    static var waitFBUsername = DispatchGroup()
    static var fb_username: String?
    //var window: UIWindow?
   //var navigationController:UINavigationController?
    
    var storyboard: UIStoryboard? {
        return UIStoryboard(name: "Main", bundle: nil)
    }
    
    class func defaultUserPool() -> AWSCognitoIdentityUserPool {
        return AWSCognitoIdentityUserPool(forKey: userPoolID)
    }
    
    //var window: UIWindow?
    
    var cognitoConfig:CognitoConfig?
          
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {

        ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
            annotation: options[UIApplication.OpenURLOptionsKey.annotation]
        )
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        //AppDelegate.waitFBUser.enter()
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        AppDelegate.loggedIn = false
        AppDelegate.fbLoggedIn = false
        
        // Initialize Pinpoint
        pinpoint = AWSPinpoint(configuration:
                AWSPinpointConfiguration.defaultPinpointConfiguration(launchOptions: launchOptions))
        // perhaps should be 8976d988-db7c-4efb-b66d-702a50d11d31
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.USEast2,
        identityPoolId:"us-east-2:8976d988-db7c-4efb-b66d-702a50d11d31")
        
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
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSPinpointAnalyticsPlugin())
            try Amplify.configure()
            print("Amplify configured with analytics plugin")
        } catch {
            print("Failed to initialize Amplify with \(error)")
        }
        print("printing access token AppDelegate")
        print(AccessToken.current)
        AppDelegate.waitFBUser.enter()
        self.fetchCurrentAuthSession()
        
        //self.window?.makeKeyAndVisible()
        // Override point for customization after application launch.
        print(AWSMobileClient.sharedInstance().getTokens)
        if let token = AccessToken.current,
            !token.isExpired {
            print("we're logged in FB")
            // User is logged in, do work such as go to next view controller.
        }
        
        _ = Amplify.Hub.listen(to: .auth) { payload in
            switch payload.eventName {
            case HubPayload.EventName.Auth.signedIn:
                DispatchQueue.main.sync{
                    //AppDelegate.fbLoggedIn = true
                    AppDelegate.waitFBUser.enter()
                    self.fetchCurrentAuthSession()
                    AppDelegate.waitFBUser.notify(queue: .main){
                        if(self.loginViewController != nil){
                            self.loginViewController?.viewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? ViewController
                            //self.loginViewController!.viewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? ViewController
                            self.loginViewController?.navigationController?.setViewControllers([self.loginViewController!.viewController!], animated: true)
                        }
                        else{
                            print("ERROR - WE SIGNED IN BUT OUR LOGINVIEW IS NIL")
                        }
                    }
                }
                // Update UI

            case HubPayload.EventName.Auth.sessionExpired:
                print("Session expired")
                // Re-authenticate the user

            case HubPayload.EventName.Auth.signedOut:
                print("User signed out")
                // Update UI

            default:
                break
            }
        }

        return AWSMobileClient.sharedInstance().interceptApplication(
            application,
            didFinishLaunchingWithOptions: launchOptions)
    }
    
    func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
        self.viewController?.encodeRestorableState(with: NSCoder())
        return true
    }
    
    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        return true
    }
    
    func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
        return true
    }
    
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
    
    /*func fetchCurrentAuthSession() {
        _ = Amplify.Auth.fetchAuthSession { result in
            switch result {
            case .success(let session):
                print("fbLoggedIn should be set to - \(session.isSignedIn)")
                print(result)
                AppDelegate.fbLoggedIn = session.isSignedIn
                //let session2 = try result.get() as! AWSAuthCognitoSession
                AppDelegate.waitFBUser.leave()
            case .failure(let error):
                print("Fetch session failed with error \(error)")
                AppDelegate.waitFBUser.leave()
            }
        }
    }*/
    
    func fetchCurrentAuthSession() {
        _ = Amplify.Auth.fetchAuthSession { result in
            do {
                print("inside fetchCurrentAuthSession2")
                let session = try result.get() as! AWSAuthCognitoSession
                print("fbLoggedIn should be set to - \(session.isSignedIn)")
                AppDelegate.fbLoggedIn = session.isSignedIn
                // Get user sub or identity id
                if let identityProvider = session as? AuthCognitoIdentityProvider {
                    let usersub = try identityProvider.getUserSub().get()
                    AppDelegate.fb_username = usersub
                    let identityId = try identityProvider.getIdentityId().get()
                    print("User sub - \(usersub) and idenity id \(identityId)")
                    print("Should have FB Username")
                    print(AppDelegate.fb_username)
                }
                // Get aws credentials
                if let awsCredentialsProvider = session as? AuthAWSCredentialsProvider {
                    let credentials = try awsCredentialsProvider.getAWSCredentials().get()
                    print("Access key - \(credentials.accessKey) ")
                }

                // Get cognito user pool token
                if let cognitoTokenProvider = session as? AuthCognitoTokensProvider {
                    let tokens = try cognitoTokenProvider.getCognitoTokens().get()
                    print("Id token - \(tokens.idToken) ")
                }
                AppDelegate.waitFBUser.leave()
            } catch {
                print("Fetch auth session failed with error - \(error)")
                AppDelegate.waitFBUser.leave()
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
        //print("inside startPasswordAuthentication AppDelegate")
        //UIApplication.shared.connectedScenes
        let hacky_scene_access = UIApplication.shared.connectedScenes.first
        let scene_delegate = hacky_scene_access?.delegate as! SceneDelegate
        /*if(AppDelegate.loggedIn!){
            print("we're logged in")
            //print("printing connected scenes from app delegate in auth")
            //print(self.window.rootViewController)
            //print(UIApplication.shared.connectedScenes)
            //print("printing scene delegate's navigationView and login view")
            //print(scene_delegate.navigationController)
            //print(scene_delegate.loginViewController)
            DispatchQueue.main.sync(execute: {
                scene_delegate.navigationController?.setViewControllers([scene_delegate.loginViewController!], animated: true)
            })
            //self.navigationController!.setViewControllers([self.loginViewController!], animated: true)
        }*/
        //print("printing scene delegate's navigationView and login view")
        //print(scene_delegate.navigationController)
        //print(scene_delegate.loginViewController)
        //print(UIApplication.shared.connectedScenes)
        return scene_delegate.loginViewController!
    }
}

// MARK: - AppDelegate Scene Lifecycle Support

extension AppDelegate {
    
    /** Called when the UIKit is about to create & vend a new UIScene instance to the application.
        Use this method to select a configuration to create the new scene with.
        The application delegate may modify the provided UISceneConfiguration within this method.
        If the UISceneConfiguration instance returned from this method does not have a systemType
        which matches the connectingSession's, UIKit will assert.
    */
    @available(iOS 13.0, *)
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        print("returning UISceneConfiguration AppDelegate")
        return UISceneConfiguration(name: "Main Scene", sessionRole: connectingSceneSession.role)
    }
    
    /** The scene session was discarded by the user.
     
        Use this method to release any resources that were specific to the discarded scenes, as they will not return.
        Remove any state or data associated with this session, as it will not return.

        Called when the system, due to a user interaction or a request from the application itself,
        removes one or more representation from the -[UIApplication openSessions] set.
     
        If any sessions were discarded while the application was not running,
        this will be called shortly after application:didFinishLaunchingWithOptions.
     */
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        //..
        print("In third application func AppDelegate")
    }

}
