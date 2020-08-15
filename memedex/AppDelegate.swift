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
import AuthenticationServices
import UserNotifications
import AWSSNS
import AVFoundation


let userPoolID = "SampleUserPool"
var pinpoint: AWSPinpoint?

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var viewController: UIViewController?
    var loginViewController: LoginViewController?
    var verificationViewController: VerificationViewController?
    static var pool: AWSCognitoIdentityUserPool?
    static var loggedIn: Bool?
    static var socialLoggedIn: Bool?
    static var waitSocialUser = DispatchGroup()
    static var waitSocialUsername = DispatchGroup()
    static var social_username:String?
    let SNSPlatformApplicationArn = "arn:aws:sns:us-west-1:560871491257:app/APNS_SANDBOX/memedex"
    
    
    var storyboard: UIStoryboard? {
        return UIStoryboard(name: "Main", bundle: nil)
    }
    
    class func defaultUserPool() -> AWSCognitoIdentityUserPool {
        return AWSCognitoIdentityUserPool(forKey: userPoolID)
    }
    
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
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        AppDelegate.loggedIn = false
        AppDelegate.socialLoggedIn = false
        let audioSession = AVAudioSession.sharedInstance()
        if audioSession.isOtherAudioPlaying {
            _ = try? audioSession.setCategory(AVAudioSession.Category.ambient, options: AVAudioSession.CategoryOptions.mixWithOthers)
        }
        
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
        print("printing access token AppDelegate (Amplify)")
        print(AccessToken.current)
        AppDelegate.waitSocialUser.enter()
        self.fetchCurrentAuthSession()
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        appleIDProvider.getCredentialState(forUserID: KeychainItem.currentUserIdentifier) { (credentialState, error) in
            switch credentialState {
            case .authorized:
                if(self.loginViewController != nil){
                    self.loginViewController?.viewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? ViewController
                    self.loginViewController?.navigationController?.setViewControllers([self.loginViewController!.viewController!], animated: true)
                }
                else{
                    print("ERROR - WE SIGNED IN BUT OUR LOGINVIEW IS NIL")
                }
                break
            case .revoked, .notFound:
                print("Error with SignInWithApple credentials")
            default:
                break
            }
        }

        // Any Amplify Event (User logins, logouts) will go through here at some point
        _ = Amplify.Hub.listen(to: .auth) { payload in
            switch payload.eventName {
            case HubPayload.EventName.Auth.signedIn:
                DispatchQueue.main.sync{
                    print("Amplify has someone signed in")
                    AppDelegate.waitSocialUser.enter()
                    self.fetchCurrentAuthSession()
                    AppDelegate.waitSocialUser.notify(queue: .main){
                        if(self.loginViewController != nil){
                            self.loginViewController?.viewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? ViewController
                            self.loginViewController?.navigationController?.setViewControllers([self.loginViewController!.viewController!], animated: true)
                        }
                        else{
                            print("ERROR - WE SIGNED IN BUT OUR LOGINVIEW IS NIL")
                        }
                    }
                }
            case HubPayload.EventName.Auth.sessionExpired:
                print("Session expired")
                // Re-authenticate the user
            case HubPayload.EventName.Auth.signedOut:
                print("Amplify user signed out")
                if(AppDelegate.loggedIn!){
                    DispatchQueue.main.async {
                        let hacky_scene_access = UIApplication.shared.connectedScenes.first
                        let scene_delegate = hacky_scene_access?.delegate as! SceneDelegate
                        scene_delegate.navigationController?.setViewControllers([scene_delegate.loginViewController!], animated: true)
                    }
                }
            default:
                break
            }
        }
        registerForPushNotifications()
        let notificationOption = launchOptions?[.remoteNotification]

        // 1
        if let notification = notificationOption as? [String: AnyObject],
            let aps = notification["aps"] as? [String: AnyObject] {
            //print("we got here from a notification")
            //print(aps)
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
    
    func fetchCurrentAuthSession() {
        _ = Amplify.Auth.fetchAuthSession { result in
            do {
                let session = try result.get() as! AWSAuthCognitoSession
                print("fbLoggedIn should be set to - \(session.isSignedIn)")
                AppDelegate.socialLoggedIn = session.isSignedIn
                // Get user sub or identity id
                if let identityProvider = session as? AuthCognitoIdentityProvider {
                    let usersub = try identityProvider.getUserSub().get()
                    AppDelegate.social_username = usersub
                    let identityId = try identityProvider.getIdentityId().get()
                    print("User sub - \(usersub) and idenity id \(identityId)")
                    print("Should have Social Username")
                    print(AppDelegate.social_username)
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
                AppDelegate.waitSocialUser.leave()
            } catch {
                print("Fetch auth session failed with error - \(error)")
                AppDelegate.waitSocialUser.leave()
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
        let hacky_scene_access = UIApplication.shared.connectedScenes.first
        let scene_delegate = hacky_scene_access?.delegate as! SceneDelegate
        if(AppDelegate.loggedIn!){
            DispatchQueue.main.async {
                scene_delegate.navigationController?.setViewControllers([scene_delegate.loginViewController!], animated: true)
            }
        }
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
    
    func getNotificationSettings() {
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        print("Notification settings: \(settings)")
        guard settings.authorizationStatus == .authorized else { return }
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
        }
      }
    }
    
    
    // Called when user opts into push notifications
    func application(
      _ application: UIApplication,
      didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
      /// Attach the device token to the user defaults
      var token = ""
      for i in 0..<deviceToken.count {
          token = token + String(format: "%02.2hhx", arguments: [deviceToken[i]])
      }
      print("Device token (SNS Push Notifications) " + token)
      UserDefaults.standard.set(token, forKey: "deviceTokenForSNS")
      /// Create a platform endpoint. In this case,  the endpoint is a
      /// device endpoint ARN
      let sns = AWSSNS.default()
      let request = AWSSNSCreatePlatformEndpointInput()
      request?.token = token
      request?.platformApplicationArn = SNSPlatformApplicationArn
      sns.createPlatformEndpoint(request!).continueWith(executor: AWSExecutor.mainThread(), block: { (task: AWSTask!) -> AnyObject? in
          if task.error != nil {
              print("Error: \(String(describing: task.error))")
          } else {
              let createEndpointResponse = task.result! as AWSSNSCreateEndpointResponse
              
              if let endpointArnForSNS = createEndpointResponse.endpointArn {
                  print("endpointArn: \(endpointArnForSNS)")
                  UserDefaults.standard.set(endpointArnForSNS, forKey: "endpointArnForSNS")
                  let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
                  let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
                  updateMapperConfig.saveBehavior = .updateSkipNullAttributes
                  let snessy = SNSEndpoint()
                if(AppDelegate.loggedIn!){
                    snessy!.sub = AppDelegate.defaultUserPool().currentUser()?.username! as! NSString
                }
                else if(AppDelegate.socialLoggedIn!){
                    snessy!.sub = AppDelegate.social_username! as! NSString
                }
                snessy?.endpoint = endpointArnForSNS as! NSString
                // VERY IMPORTANT
                // We need to send our SNS Endpoint to Dynamo
                // We will use it to send push notifications to a particular device
                // When memes or messages are added to groups
                  dynamoDBObjectMapper.save(snessy!, configuration: updateMapperConfig).continueWith(block: { (task:AWSTask<AnyObject>!) -> Any? in
                      if let error = task.error as NSError? {
                          print("The request failed. Error: \(error)")
                      } else {
                          print("Endpoint should have been sent")
                          // Do something with task.result or perform other operations.
                      }
                      return 0
                  })
              }
          }
          return nil
      })
    }

    func application(
      _ application: UIApplication,
      didFailToRegisterForRemoteNotificationsWithError error: Error) {
      print("Failed to register: \(error)")
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                                    fetchCompletionHandler completionHandler:
        @escaping (UIBackgroundFetchResult) -> Void) {

        pinpoint!.notificationManager.interceptDidReceiveRemoteNotification(
            userInfo, fetchCompletionHandler: completionHandler)
        print("didReceiveRemoteNotification pinpoint")
    }
    
    // Request user to grant permissions for the app to use notifications
    func registerForPushNotifications() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge]) {
            (granted, error) in
            print("Permission granted for push notifications: \(granted)")
            // 1. Check if permission granted
            guard granted else { return }
            // 2. Attempt registration for remote notifications on the main thread
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    // Called when a notification is delivered to a foreground app.
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("Got here through notification")
        
        let collection_view = self.storyboard?.instantiateViewController(withIdentifier: "CollectionViewController") as? CollectionViewController
        collection_view!.group = "MITCHELL ROSE CLICK HERE"
        DispatchQueue.main.async {
            let hacky_scene_access = UIApplication.shared.connectedScenes.first
            let scene_delegate = hacky_scene_access?.delegate as! SceneDelegate
            scene_delegate.navigationController?.setViewControllers([collection_view!], animated: true)
        }
        print("User Info = ",notification.request.content.userInfo)
        completionHandler([.alert, .badge, .sound])
    }
    
    // Called to let your app know which action was selected by the user for a given notification.
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("Got here through notification")
        let collection_view = self.storyboard?.instantiateViewController(withIdentifier: "CollectionViewController") as? CollectionViewController
        collection_view!.group = "MITCHELL ROSE CLICK HERE"
        DispatchQueue.main.async {
            let hacky_scene_access = UIApplication.shared.connectedScenes.first
            let scene_delegate = hacky_scene_access?.delegate as! SceneDelegate
            scene_delegate.navigationController?.setViewControllers([collection_view!], animated: true)
        }
        print("User Info = ",response.notification.request.content.userInfo)
        completionHandler()
    }

}
