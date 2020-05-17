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

class LoginViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var signup_requirements: UILabel!
    
    @IBOutlet weak var email: UITextField!
    
    @IBOutlet weak var password: UITextField!
    
    @IBOutlet weak var loginButton: UIButton!
    
    var user: AWSCognitoIdentityUser?
    
    var cognitoConfig:CognitoConfig?
    
    var userAttributes:[AWSCognitoIdentityProviderAttributeType]?
    
    var passwordAuthenticationCompletion: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>?
    
    var activityIndicator = UIActivityIndicatorView()
    
    //let waitUserInfo = DispatchGroup()
    
    override func viewWillAppear(_ animated: Bool) {
        print("In loginViewController")
        self.activityIndicator = UIActivityIndicatorView()
        //self.activityIndicator.
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
        print(self.user)
        print(self.user?.username)
        print(self.user?.isSignedIn)
        if (appDelegate.navigationController == nil){
            appDelegate.navigationController = appDelegate.window?.rootViewController as? UINavigationController
        }
        //self.waitUserInfo.enter()
        //self.fetchUserAttributes()
        //self.waitUserInfo.notify(queue: .main){
        print("In loginViewController2")
            if(self.user?.isSignedIn ?? false){
                print("We have a user that's signed in")
                //AppDelegate.loggedIn = true
                appDelegate.viewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? ViewController
                (appDelegate.viewController as! ViewController).user = self.user
                appDelegate.navigationController?.setViewControllers([appDelegate.viewController!], animated: true)
                //AppDelegate.loggedIn = true
            }
        print("In loginViewController3")
            print("IN VIEW WILL APPEAR LOGIN")
            self.password?.addTarget(self, action: #selector(self.inputDidChange(_:)), for: .editingChanged)
            self.email?.addTarget(self, action: #selector(self.inputDidChange(_:)), for: .editingChanged)
            self.cognitoConfig = CognitoConfig()
            self.password.delegate = self
            self.email.delegate = self
            let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
            self.view.addGestureRecognizer(tap)
            print("End of view will appear login view")
            //print("This is the user in the LoginViewController " + String((AppDelegate.defaultUserPool().currentUser()?.username!)!))
            //print("Their attributes below")
            //print(AppDelegate.defaultUserPool().currentUser()?.getDetails())
            //print("Again but the local variable " + String(self.user!.username!))
            print("Their attributes below")
            //print(self.user!.getDetails())
        
            if(AppDelegate.loggedIn!){
                AppDelegate.loggedIn = false
            }
            self.user?.getDetails()
        //}
    }
    
    @IBAction func login(_ sender: Any) {
        //print("here8")
        if (self.email?.text != nil && self.password?.text != nil) {
           // print("here8.2")
            let authDetails = AWSCognitoIdentityPasswordAuthenticationDetails(username: self.email!.text!, password: self.password!.text! )
            print(authDetails)
            //print("here8.3")
            self.passwordAuthenticationCompletion?.set(result: authDetails)
            print(self.passwordAuthenticationCompletion)
            /*if(self.user?.username == nil){
                self.user?.getDetails()
            }*/
            //print("here8.4")
        }
        print("End of login loginview")
    }
    
    /*func dismissMe() {
        print("made it here")
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.viewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? ViewController
        (appDelegate.viewController as! ViewController).user = self.user
        (appDelegate.viewController as! ViewController).userAttributes = self.userAttributes
        appDelegate.navigationController?.setViewControllers([appDelegate.viewController!], animated: true)
        self.dismiss(animated: true, completion: {
            self.email.text = nil
            self.password.text = nil
        })
    }*/
    
    
    @IBOutlet weak var signup_button: UIButton!
    @IBAction func signup(_ sender: Any) {
        self.activityIndicator.startAnimating()
        print("inside signup")
        print("The user inside LoginViewController's signup is below")
        print(self.user)
        print(self.userAttributes)
        //let staticCredentialProvider = AWSStaticCredentialsProvider.init(accessKey: self.cognitoConfig!.getClientId(), secretKey: self.cognitoConfig!.getClientSecret())
        
        //let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.USEast2,
        //let configuration = AWSServiceConfiguration.init(region:.USEast2, credentialsProvider:staticCredentialProvider)
        //AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        let email = AWSCognitoIdentityUserAttributeType()
        //let password = AWSCognitoIdentityUserAttributeType()
        let name = AWSCognitoIdentityUserAttributeType()
        email!.value = self.email.text
        email!.name = "email"
        
        if(self.email.text == nil || self.password.text == nil || self.email.text == "" || self.password.text == ""){
            print("inside here in signup")
            self.activityIndicator.stopAnimating()
            let alert = UIAlertController(title: "Signing Up", message: "Enter your email and a password before clicking 'Sign Up'. Don't worry, we won't send you any emails or ask for additional data :)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: nil))
            self.present(alert, animated: true)
            return
        }
        //password!.value = self.password.text
        //password!.name = "password"
        //name!.value = self.email.text
        //name!.name = "username"
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if(appDelegate.viewController == nil){
            print("our view controller is nil")
            appDelegate.viewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? ViewController
        }
        if(appDelegate.verificationViewController != nil){
            print("we already tried to verify an email")
            if(appDelegate.verificationViewController?.email == email!.value){
                print("They are trying to sign up an account that they already inputted but haven't verified. Eventually we should find a way to update the password here")
                self.activityIndicator.stopAnimating()
                self.password.text = appDelegate.verificationViewController?.password
                self.performSegue(withIdentifier: "VerifySegue", sender: self)
                return
            }
        }
        //print(AppDelegate.pool)
        print("About to call AppDelegate.pool.signup")
        AppDelegate.pool?.signUp(self.email.text!, password: self.password.text!, userAttributes: [email!], validationData: nil).continueWith{ (response) -> Any? in
            if response.error != nil {
                let alert = UIAlertController(title: "Error", message: (response.error! as NSError).userInfo["message"] as? String, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler:nil))
                self.present(alert, animated: true, completion: nil)
            }
            else{
                //guard let print_me = response.result; print(print_me); else print("wasn't printed")
                //print("here")
                print("INSIDE OF LOGINVIEW LOOKING AT SIGNUP STUFF")
                print(response.result)
                print(response.result?.user)
                print(response.result?.userSub)
                print(self.user)
                print(AppDelegate.pool?.currentUser())
                print(AppDelegate.pool?.getUser())
                self.user = response.result?.user
                //AppDelegate.defaultUserPool().
                //self.userAttributes = response.result?.user.a
                // need to instantiate a viewcontroller in the event that they verify later
                //print("herey")
                //print(response)
                //print(response.result)
                //self.user = response.result?.user
                print("About to perform segue to verification view controller")
                DispatchQueue.main.async {
                    //self.codeDeliveryDetails = response.result?.codeDeliveryDetails
                    self.activityIndicator.stopAnimating()
                    self.performSegue(withIdentifier: "VerifySegue", sender: self)
                }
                //self.performSegue(withIdentifier: "VerifySegue", sender: self)
            }
            return 1
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let verificationController = segue.destination as! VerificationViewController
        verificationController.isModalInPresentation = true
        //verificationController.codeDeliveryDetails = self.codeDeliveryDetails
        verificationController.user = self.user!
    }
    
    @objc func inputDidChange(_ sender:AnyObject) {
        //print("here9")
        if (self.email?.text != nil && self.password?.text?.count ?? 0 > 7) {
            self.loginButton?.isEnabled = true
            self.signup_button?.isEnabled = true
            self.signup_requirements.isHidden = true
        } else {
            self.loginButton?.isEnabled = false
            self.signup_button?.isEnabled = false
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
    

    /*func fetchUserAttributes() {
        //print("fetching user attributes")
        print("beginning of fetch attributes")
        user = AppDelegate.defaultUserPool().currentUser()
        print(user?.username)
        user?.getDetails().continueOnSuccessWith(block: { (task) -> Any? in
            guard task.result != nil else {
                print("end of fetch attributes [FAIL]")
                //self.waitUserInfo.leave()
                return nil
            }
            //print("22222in this part of fetchuserattributes")
            self.userAttributes = task.result?.userAttributes
            self.userAttributes?.forEach({ (attribute) in
                print("Name: " + attribute.name!)
                print("Value: " + attribute.value!)
            })
            print("end of fetch attributes [SUCCESS]")
            //self.waitUserInfo.leave()
            DispatchQueue.main.async {
                print("fetch attributes is actually done")
                print("end of fetch attributes [SUCCESS]")
                //print("444444in this part of fetchuserattributes")
                //print("fetched attribute values")
            }
            //print("fetch attributes is actually done")
            return nil
        })
    }*/
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension LoginViewController: AWSCognitoIdentityPasswordAuthentication {
    public func getDetails(_ authenticationInput: AWSCognitoIdentityPasswordAuthenticationInput, passwordAuthenticationCompletionSource: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>) {
        print("here in login get details")
        self.passwordAuthenticationCompletion = passwordAuthenticationCompletionSource
        DispatchQueue.main.async {
            if (self.email.text == nil) {
                //self.email.text = authenticationInput.lastKnownUsername
                //print("herey")
            }
        }
    }
    
    public func didCompleteStepWithError(_ error: Error?) {
        DispatchQueue.main.async {
            if let error = error as NSError? {
                let alertController = UIAlertController(title: error.userInfo["__type"] as? String,
                                                        message: error.userInfo["message"] as? String,
                                                        preferredStyle: .alert)
                let retryAction = UIAlertAction(title: "Retry", style: .default, handler: nil)
                alertController.addAction(retryAction)
                
                self.present(alertController, animated: true, completion:  nil)
            } else {
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                if (!AppDelegate.loggedIn!){
                    print("logging in loginview")
                    self.email.text = nil
                    self.password.text = nil
                    //appDelegate.viewController = nil
                    appDelegate.viewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? ViewController
                    //(appDelegate.viewController as! ViewController).user = self.user
                    //(appDelegate.viewController as! ViewController).userAttributes = self.userAttributes
                    let temp_old_name = AppDelegate.defaultUserPool().currentUser()?.username
                    // wait until user is updated
                    // i am a piece of human garbage
                    var observer:NSKeyValueObservation?
                    //observer = AppDelegate.defaultUserPool().currentUser()?.username.ob
                    var hundredth_second_count = 0
                    while(temp_old_name == AppDelegate.defaultUserPool().currentUser()?.username){
                        //print("In this username loop")
                        // waited a whole ass second
                        // They logged in as the same person who was logged in last time
                        if(hundredth_second_count == 100){
                            break
                        }
                        // one hundredth of a second
                        usleep(10000)
                        hundredth_second_count = hundredth_second_count + 1
                    }
                    appDelegate.navigationController?.setViewControllers([appDelegate.viewController!], animated: true)
                    //AppDelegate.loggedIn = true
                }
                else{
                    print("logging out loginview")
                }
            }
        }
    }
}
