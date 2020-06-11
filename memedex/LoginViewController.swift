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
    
    var go_to_golden = false

    var viewController:ViewController?
    
    var goldenSetViewController:GoldenSetViewController?
    
    override func viewWillAppear(_ animated: Bool) {
        if (self.password?.text?.count ?? 0 > 7) {
            self.loginButton?.isEnabled = true
            self.signup_button?.isEnabled = true
            self.signup_requirements.isHidden = true
        } else {
            self.loginButton?.isEnabled = false
            //self.signup_button?.isEnabled = false
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
        
        //if (appDelegate.navigationController == nil){
         //   appDelegate.navigationController = appDelegate.window?.rootViewController as? UINavigationController
        //}
        
        print("finding out if the user is signed in loginView")
        print(self.user?.isSignedIn)
        
        // User is already signed in
        if(self.user?.isSignedIn ?? false){
            print("printing our window loginView")
            print(self.view.window)
            print("should be transitioning to viewController")
            print(appDelegate)
            self.viewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? ViewController
            print(self.viewController)
            self.viewController!.user = self.user
            print(self.navigationController)
            // should be the same as accessing from scene delegate
            self.navigationController?.setViewControllers([self.viewController!], animated: true)
            //let sceneDelegate = UIApplication.shared.delegate as! SceneDelegate
            //sceneDelegate.navigationController?.setViewControllers([appDelegate.viewController!], animated: true)
            print("should have transitioned to view controller")
        }
        
        self.password?.addTarget(self, action: #selector(self.inputDidChange(_:)), for: .editingChanged)
        self.email?.addTarget(self, action: #selector(self.inputDidChange(_:)), for: .editingChanged)
        self.cognitoConfig = CognitoConfig()
        self.password.delegate = self
        self.email.delegate = self
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
        if(AppDelegate.loggedIn!){
            AppDelegate.loggedIn = false
        }
        self.user?.getDetails()
    }
    
    @IBAction func login(_ sender: Any) {
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
            self.go_to_golden = true
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
                    self.go_to_golden = true
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
            print("presenting valid email error")
            self.activityIndicator.stopAnimating()
            let alert = UIAlertController(title: "Invalid Email", message: "The email address entered is invalid", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Retry", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
        // Password isn't long enough
        else if(self.password.text?.count ?? 0 < 8){
            print("presenting valid password error")
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
                    let alertController = UIAlertController(title: "Account does not exist",
                                                            message: "Try signing in again or signing up",
                                                            preferredStyle: .alert)
                    let retryAction = UIAlertAction(title: "Retry", style: .default, handler: nil)
                    alertController.addAction(retryAction)
                    self.present(alertController, animated: true, completion:  nil)
                }
                else{
                    DispatchQueue.main.async {
                        self.go_to_golden = true
                        self.performSegue(withIdentifier: "VerifySegue", sender: self)
                    }
                }
            } else {
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                if (!AppDelegate.loggedIn!){
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
                    if(!self.go_to_golden){
                        let hacky_scene_access = UIApplication.shared.connectedScenes.first
                        let scene_delegate = hacky_scene_access?.delegate as! SceneDelegate
                        scene_delegate.viewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? ViewController
                        scene_delegate.navigationController?.setViewControllers([scene_delegate.viewController!], animated: true)
                    }
                    else{
                        self.goldenSetViewController = self.storyboard?.instantiateViewController(withIdentifier: "GoldenSetViewController") as? GoldenSetViewController
                        self.go_to_golden = false
                        self.navigationController?.setViewControllers([(self.goldenSetViewController!)], animated: true)
                    }
                }
                else{
                    print("logging out loginview")
                }
            }
        }
    }
}


