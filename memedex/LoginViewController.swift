//
//  LoginViewController.swift
//  memedex
//
//  Created by meagh054 on 3/31/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import AWSCognito
import AWSCognitoIdentityProvider
import FBSDKLoginKit
import Amplify
import AuthenticationServices

class LoginViewController: UIViewController, UITextFieldDelegate, LoginButtonDelegate, ASAuthorizationControllerDelegate{
    
    func loginButtonDidLogOut(_ loginButton: FBLoginButton) {
        print("here inside loginButtonDidLogOut")
        print(self.user?.username)
        _ = Amplify.Auth.signOut() { result in
            switch result {
            case .success:
                print("Successfully signed out")
            case .failure(let error):
                print("Sign out failed with error \(error)")
            }
        }
        //self.user?.signOut()
        print(Amplify.Auth.getCurrentUser())
        //Amplify.Auth.sign
        Amplify.Auth.getCurrentUser()
        /*LoginManager.logOut(<#T##self: LoginManager##LoginManager#>)
        Amplify.Auth.signOut(options: [], listener: <#T##((AmplifyOperation<AuthSignOutRequest, Void, AuthError>.OperationResult) -> Void)?##((AmplifyOperation<AuthSignOutRequest, Void, AuthError>.OperationResult) -> Void)?##(AmplifyOperation<AuthSignOutRequest, Void, AuthError>.OperationResult) -> Void#>)
        Amplify.Auth.signOut(listener: ((AmplifyOperation<AuthSignOutRequest, Void, AuthError>.OperationResult) -> Void)?)*/
    }
    
    
    func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?) {
        print("here inside loginButton - logged in")
        /*let hacky_scene_access = UIApplication.shared.connectedScenes.first
        let scene_delegate = hacky_scene_access?.delegate as! SceneDelegate
        _ = Amplify.Auth.signInWithWebUI(for: .facebook, presentationAnchor: scene_delegate.window!) { result in
            switch result {
            case .success(_):
                print("Sign in succeeded")
            case .failure(let error):
                print("Sign in failed \(error)")
                print(result)
                print("babababa")
            }
        }*/
    }
    
    @IBOutlet weak var signup_requirements: UILabel!
    
    @IBOutlet weak var email: UITextField!
    
    @IBOutlet weak var password: UITextField!
    
    @IBOutlet weak var loginButton: UIButton!
    
    var user: AWSCognitoIdentityUser?
    
    var cognitoConfig:CognitoConfig?
    
    var userAttributes:[AWSCognitoIdentityProviderAttributeType]?
    
    var passwordAuthenticationCompletion: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>?
    
    var activityIndicator = UIActivityIndicatorView()

    var viewController:ViewController?
    
    var loginButton2:FBLoginButton?
    
    var appleLoginButton:ASAuthorizationAppleIDButton?
    
    
    override func viewWillAppear(_ animated: Bool) {
        
        // SET UP FB LOGIN BUTTON FIRST BECAUSE THAT TAKES A SECOND
        if(self.loginButton2 == nil){
            self.loginButton2 = FBLoginButton()
            self.loginButton2!.center = self.view.center
            print("printing targets for loginButton2")
            print(self.loginButton2!.allTargets)
            //var temp_origin = self.view.frame.origin.
            //temp_origin.y = temp_origin.y + 100
            //self.loginButton2!.frame.origin = temp_origin
            //loginButton2.frame.origin.x += 60
            self.loginButton2!.permissions = ["public_profile", "email"]
            self.loginButton2!.removeTarget(nil, action: nil, for: .allEvents)
            //loginButton2.delegate = self
            self.loginButton2!.addTarget(self, action: (#selector(self.fbLogin)), for: .touchUpInside)
            NotificationCenter.default.addObserver(forName: .AccessTokenDidChange, object: nil, queue: OperationQueue.main) { (notification) in
                // Print out access token
                print("FB Access Token: \(String(describing: AccessToken.current?.tokenString))")
            }
            //print("printing access token")
            //print(AccessToken.current)
            //loginButton2.addTarget(self, action:Selector(("fbLoginClicked:")), for: UIControl.Event.touchUpInside)
            print("printing login button frame")
            print(self.loginButton2?.frame)
            self.loginButton2?.isHidden = false
            print("printing signup button frame")
            print(self.signup_button.frame)
            self.view.addSubview(self.loginButton2!)
            self.loginButton2!.translatesAutoresizingMaskIntoConstraints = false
            self.loginButton2?.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
            //self.loginButton2?.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -175).isActive = true
            self.loginButton2!.center.x = self.view.center.x
            self.view.setNeedsDisplay()
        }
        
        if (self.password?.text?.count ?? 0 > 7) {
            self.loginButton?.isEnabled = true
            self.signup_button?.isEnabled = true
            self.signup_requirements.isHidden = true
        } else {
            self.loginButton?.isEnabled = false
            self.signup_requirements.isHidden = false
        }

        self.activityIndicator = UIActivityIndicatorView()
        self.activityIndicator.color = UIColor.gray
        self.activityIndicator.style = UIActivityIndicatorView.Style.large
        self.activityIndicator.frame = CGRect(x: self.view.bounds.midX - 50, y: self.view.bounds.midY - 100, width: 100, height: 100)
        self.activityIndicator.hidesWhenStopped = true
        self.activityIndicator.layer.zPosition = 1
        view.addSubview(self.activityIndicator)
        
        self.signup_requirements.isHidden = true
        super.viewWillAppear(animated)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.loginViewController = self
        
        if(self.user == nil){
            self.user = AppDelegate.defaultUserPool().currentUser()
        }

        AppDelegate.waitSocialUser.notify(queue: .main){
            print("notified LoginView")
            if((self.user?.isSignedIn ?? false) && AppDelegate.socialLoggedIn!){
                print("Both a social user and non social user are logged in, this shouldn't happen")
            }
            // Non-FB User is already signed in
            if(self.user?.isSignedIn ?? false){
                self.viewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? ViewController
                self.viewController!.user = self.user
                self.navigationController?.setViewControllers([self.viewController!], animated: true)
            }
            if(AppDelegate.socialLoggedIn!){
                self.viewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? ViewController
                self.navigationController?.setViewControllers([self.viewController!], animated: true)
            }
        
        
        self.password?.addTarget(self, action: #selector(self.inputDidChange(_:)), for: .editingChanged)
        self.email?.addTarget(self, action: #selector(self.inputDidChange(_:)), for: .editingChanged)
        self.cognitoConfig = CognitoConfig()
        self.password.delegate = self
        self.email.delegate = self
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
            
        // for setting up Apple Login
        self.setupProviderLoginView()
        
        if(AppDelegate.loggedIn!){
            AppDelegate.loggedIn = false
        }
        self.user?.getDetails()
        }
    }
    
    
    // SET UP APPLE LOGIN BUTTON
    func setupProviderLoginView() {
        print("inside setupProviderLoginView")
        self.appleLoginButton = ASAuthorizationAppleIDButton()
        self.appleLoginButton?.isUserInteractionEnabled = true
        self.appleLoginButton!.removeTarget(nil, action: nil, for: .allEvents)
        self.appleLoginButton!.addTarget(self, action: #selector(self.handleAuthorizationAppleIDButtonPress), for: .allEvents)
        self.view.addSubview(self.appleLoginButton!)
        self.appleLoginButton!.translatesAutoresizingMaskIntoConstraints = false
        self.appleLoginButton!.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        //self.appleLoginButton!.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -100).isActive = true
        self.appleLoginButton!.center.x = self.view.center.x
        var temp_frame = self.appleLoginButton?.frame
        self.view.addConstraint(NSLayoutConstraint(item: self.appleLoginButton, attribute: .trailing, relatedBy: .equal, toItem: self.view, attribute: .trailing, multiplier: 1, constant: -35))
        self.view.addConstraint(NSLayoutConstraint(item: self.appleLoginButton, attribute: .leading, relatedBy: .equal, toItem: self.view, attribute: .leading, multiplier: 1, constant: 35))
        self.view.addConstraint(NSLayoutConstraint(item: self.appleLoginButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute,multiplier: 1, constant: 48))
        self.view.addConstraint(NSLayoutConstraint(item: self.loginButton2, attribute: .trailing, relatedBy: .equal, toItem: self.view, attribute: .trailing, multiplier: 1, constant: -35))
        self.view.addConstraint(NSLayoutConstraint(item: self.loginButton2, attribute: .leading, relatedBy: .equal, toItem: self.view, attribute: .leading, multiplier: 1, constant: 35))
        self.view.addConstraint(NSLayoutConstraint(item: self.loginButton2, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute,multiplier: 1, constant: 48))
        
        self.view.addConstraint(NSLayoutConstraint(item: self.appleLoginButton, attribute: .top, relatedBy: .equal, toItem: self.loginButton2, attribute: .bottom, multiplier: 1, constant: 20))
        self.view.addConstraint(NSLayoutConstraint(item: self.loginButton2, attribute: .top, relatedBy: .equal, toItem: self.signup_button, attribute: .bottom, multiplier: 1, constant: 20))
    }
    
    // FOR APPLE SIGN IN
    @objc func handleAuthorizationAppleIDButtonPress() {
        _ = Amplify.Auth.signInWithWebUI(for: .apple, presentationAnchor: self.view.window!) { result in
            switch result {
            case .success(_):
                print("Apple Sign in succeeded")
            case .failure(let error):
                print("Sign in failed \(error)")
                print(result)
                print("babababa")
            }
        }
        /*self.performExistingAccountSetupFlows()
        print("inside handleAuthorizationAppleIDButtonPress")
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()*/
    }
    
    // FOR APPLE SIGN IN
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        switch authorization.credential {
        case let appleIDCredential as ASAuthorizationAppleIDCredential:
            print("in this part")
            
            /*let userIdentifier = appleIDCredential.user
            let fullName = appleIDCredential.fullName
            let email = appleIDCredential.email
            let cognito_conversion = AWSCognitoIdentityUser()
            Amplify.Auth.signUp(username: userIdentifier, password: "password", options: nil, listener: nil)
            AppDelegate.appleLoggedIn = true
            AppDelegate.apple_username = userIdentifier
            //cognito_conversion.username = userIdentifier
            //c//ognito_conversion.isSignedIn = true
            //AppDelegate.defaultUserPool().currentUser() = cognito_conversion
            self.viewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? ViewController
            self.navigationController?.setViewControllers([self.viewController!], animated: true)*/
        case let passwordCredential as ASPasswordCredential:
            print("in this part2")
            // Sign in using an existing iCloud Keychain credential.
            let username = passwordCredential.user
            let password = passwordCredential.password
            self.viewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? ViewController
            self.navigationController?.setViewControllers([self.viewController!], animated: true)
        default:
            break
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("inside this thing")
        print(error)
        // Handle error.
    }
    
    private func showPasswordCredentialAlert(username: String, password: String) {
        let message = "The app has received your selected credential from the keychain. \n\n Username: \(username)\n Password: \(password)"
        let alertController = UIAlertController(title: "Keychain Credential Received",
                                                message: message,
                                                preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    func performExistingAccountSetupFlows() {
        print("inside performExistingAccountSetupFlows")
        // Prepare requests for both Apple ID and password providers.
        let requests = [ASAuthorizationAppleIDProvider().createRequest(),
                        ASAuthorizationPasswordProvider().createRequest()]
        
        // Create an authorization controller with the given requests.
        let authorizationController = ASAuthorizationController(authorizationRequests: requests)
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    
    
    
    @objc func fbLogin(sender: FBLoginButton){
        print("here inside custom-made fbLogin")
        let hacky_scene_access = UIApplication.shared.connectedScenes.first
        let scene_delegate = hacky_scene_access?.delegate as! SceneDelegate
        //self.view.window = scene_delegate.window!
        _ = Amplify.Auth.signInWithWebUI(for: .facebook, presentationAnchor: self.view.window!) { result in
            switch result {
            case .success(_):
                print("FB Sign in succeeded")
            case .failure(let error):
                print("Sign in failed \(error)")
                print(result)
                print("babababa")
            }
        }
        //sleep(5)
    }
    
    @IBAction func login(_ sender: Any) {
        self.activityIndicator.startAnimating()
        if (self.email?.text != nil && self.password?.text != nil) {
            let authDetails = AWSCognitoIdentityPasswordAuthenticationDetails(username: self.email!.text!, password: self.password!.text! )
            self.passwordAuthenticationCompletion?.set(result: authDetails)
        }
    }
    
    @IBOutlet weak var signup_button: UIButton!
    @IBAction func signup(_ sender: Any) {
        self.activityIndicator.startAnimating()
        let email = AWSCognitoIdentityUserAttributeType()
        let name = AWSCognitoIdentityUserAttributeType()
        email!.value = self.email.text
        email!.name = "email"
        
        if(self.email.text == nil || self.password.text == nil || self.email.text == "" || self.password.text == ""){
            self.activityIndicator.stopAnimating()
            self.performSegue(withIdentifier: "SignUpSegue", sender: self)
            return
        }
        
        //let appDelegate = UIApplication.shared.delegate as! AppDelegate
        //if(appDelegate.viewController == nil){
        //    print("our view controller is nil")
         //   appDelegate.viewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? ViewController
        //}
        
        // Enough info to sign up
        if((self.email.text?.isValidEmail())! && self.password.text?.count ?? 0 > 7){
            AppDelegate.pool?.signUp(self.email.text!, password: self.password.text!, userAttributes: [email!], validationData: nil).continueWith{ (response) -> Any? in
                if response.error != nil {
                    let casted = response.error! as NSError
                    print(casted)
                    DispatchQueue.main.async{
                        let authDetails = AWSCognitoIdentityPasswordAuthenticationDetails(username: self.email!.text!, password: self.password!.text! )
                        self.passwordAuthenticationCompletion?.set(result: authDetails)
                    }
                }
                else{
                    self.user = response.result?.user
                    DispatchQueue.main.async {
                        self.activityIndicator.stopAnimating()
                        self.performSegue(withIdentifier: "VerifySegue", sender: self)
                    }
                }
                return 1
            }
        }
        // Email isn't valid
        else if(!(self.email.text?.isValidEmail())!){
            //print("presenting valid email error")
            self.activityIndicator.stopAnimating()
            let alert = UIAlertController(title: "Invalid Email", message: "The email address entered is invalid", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Retry", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
        // Password isn't long enough
        else if(self.password.text?.count ?? 0 < 8){
            //print("presenting valid password error")
            self.activityIndicator.stopAnimating()
            let alert = UIAlertController(title: "Password too short", message: "Password needs to be at least 8 characters", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Retry", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if(segue.identifier == "SignUpSegue"){
            let signupController = segue.destination as! SignUpViewController
            signupController.isModalInPresentation = true
            signupController.user = self.user
            signupController.userAttributes = self.userAttributes
        }
        else{
            let verificationController = segue.destination as! VerificationViewController
            verificationController.isModalInPresentation = true
            verificationController.user = self.user!
            verificationController.email = self.email.text!
            verificationController.password = self.password.text!
        }
    }
    
    @objc func inputDidChange(_ sender:AnyObject) {
        if (self.email?.text != nil && self.password?.text?.count ?? 0 > 7) {
            self.loginButton?.isEnabled = true
            self.signup_button?.isEnabled = true
            self.signup_requirements.isHidden = true
        } else {
            self.loginButton?.isEnabled = false
            self.signup_requirements.isHidden = false
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

}

extension LoginViewController: AWSCognitoIdentityPasswordAuthentication {
    public func getDetails(_ authenticationInput: AWSCognitoIdentityPasswordAuthenticationInput, passwordAuthenticationCompletionSource: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>) {
        print("inside getDetails loginView")
        self.passwordAuthenticationCompletion = passwordAuthenticationCompletionSource
        /*DispatchQueue.main.async {
            if (self.email.text == nil) {
                print("in login get details and an email is nil... not sure what's up")
            }
        }*/
    }
    
    public func didCompleteStepWithError(_ error: Error?) {
        print("inside didCompleteStepWithError LoginView")
        DispatchQueue.main.async {
            if let error = error as NSError? {
                let casted = error as NSError
                if((casted.userInfo["__type"] as! String) == "NotAuthorizedException"){
                    self.activityIndicator.stopAnimating()
                    let alertController = UIAlertController(title: "Account does not exist",
                                                            message: "Try signing in again or signing up",
                                                            preferredStyle: .alert)
                    let retryAction = UIAlertAction(title: "Retry", style: .default, handler: nil)
                    alertController.addAction(retryAction)
                    self.present(alertController, animated: true, completion:  nil)
                }
                else{
                    self.activityIndicator.stopAnimating()
                    DispatchQueue.main.async {
                        self.performSegue(withIdentifier: "VerifySegue", sender: self)
                    }
                }
            } else {
                print("here LoginView22222")
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                if (!(AppDelegate.loggedIn!)){
                    print("we are logging in loginview")
                    self.email.text = nil
                    self.password.text = nil
                    let temp_old_name = AppDelegate.defaultUserPool().currentUser()?.username
                    var hundredth_second_count = 0
                    while(temp_old_name == AppDelegate.defaultUserPool().currentUser()?.username){
                        if(hundredth_second_count == 100){
                            break
                        }
                        // one hundredth of a second
                        usleep(10000)
                        hundredth_second_count = hundredth_second_count + 1
                    }
                    self.activityIndicator.stopAnimating()
                    let hacky_scene_access = UIApplication.shared.connectedScenes.first
                    let scene_delegate = hacky_scene_access?.delegate as! SceneDelegate
                    scene_delegate.viewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as! ViewController
                    scene_delegate.viewController!.user = self.user
                    scene_delegate.navigationController?.setViewControllers([scene_delegate.viewController!], animated: true)
                }
                else{
                    print("we are logging out loginview")
                    AppDelegate.loggedIn = false
                }
            }
        }
    }
}

extension LoginViewController: ASAuthorizationControllerPresentationContextProviding {
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        print("in presentationAnchor")
        return self.view.window!
    }
}


