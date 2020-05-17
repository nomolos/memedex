//
//  VerificationViewController.swift
//  memedex
//
//  Created by meagh054 on 4/9/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import AWSCognitoIdentityProvider

class VerificationViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var code: UITextField!
    @IBOutlet weak var verifyButton: UIButton!
    
    var user: AWSCognitoIdentityUser?
    var userAttributes:[AWSCognitoIdentityProviderAttributeType]?
    var email:String?
    var password:String?
    var passwordAuthenticationCompletion: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>?
    var activityIndicator = UIActivityIndicatorView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let alert = UIAlertController(title: "Check your email!", message: "You should have received an email with a code. Type it in here to confirm your account.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: nil))
        self.present(alert, animated: true)
        self.activityIndicator = UIActivityIndicatorView()
        //self.activityIndicator.
        self.activityIndicator.color = UIColor.gray
        self.activityIndicator.style = UIActivityIndicatorView.Style.large
        self.activityIndicator.frame = CGRect(x: self.view.bounds.midX - 50, y: self.view.bounds.midY - 100, width: 100, height: 100)
        self.activityIndicator.hidesWhenStopped = true
        self.activityIndicator.layer.zPosition = 1
        view.addSubview(self.activityIndicator)
        //let appDelegate = UIApplication.shared.delegate as! AppDelegate
        //print("These two users should be the same (hope to god)")
        //print(AppDelegate.defaultUserPool().getUser().username)
        //self.user = AppDelegate.defaultUserPool().currentUser()
        //print(self.user?.username)
        //print("This is the user in the VerificationViewControllerString((AppDelegate.defaultUserPool().currentUser()?.username!)!))
        //print("Their attributes below")
        //print(AppDelegate.defaultUserPool().currentUser()?.getDetails())
        //print("Again but the local variable " + String(self.user!.username!))
        //print("Their attributes below")
        //self.fetchUserAttributes()
        //sleep(3)
        self.code.addTarget(self, action: #selector(inputDidChange(_:)), for: .editingChanged)
        self.code.delegate = self
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.verificationViewController = self
        self.user = appDelegate.loginViewController?.user
        self.email = appDelegate.loginViewController?.email.text
        self.password = appDelegate.loginViewController?.password.text
        // Do any additional setup after loading the view.
    }
    
    @IBAction func verify(_ sender: Any) {
        print("attempting to verify")
        self.activityIndicator.startAnimating()
        self.user?.confirmSignUp(code.text!)
        .continueWith(block: { (response) -> Any? in
            if response.error != nil {
                DispatchQueue.main.async {
                    print("verifying didn't work")
                    self.code.text = ""
                    self.activityIndicator.stopAnimating()
                    let alert = UIAlertController(title: "Error", message: "This code doesn't work. Try going back and signing up again.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Retry", style: .default, handler: nil))
                    self.present(alert, animated: true, completion:nil)
                }
            } else {
                DispatchQueue.main.async {
                    //print("Emptying pool since the older user aint here anymore")
                    //AppDelegate.pool?.clearAll()
                    print("verifying did work, showing response below :")
                    //sleep(3)
                    print(response.result)
                    print("User info below")
                    print(self.user)
                    print(self.user?.username)
                    print(self.user?.confirmedStatus)
                    print("end of verification - attempting to log this user in")
                    print("printing email and password")
                    print(self.email)
                    print(self.password)
                    
                    /*if(AppDelegate.defaultUserPool().currentUser()?.username == nil){
                        self.user.getDetails()
                    }*/
                    self.activityIndicator.stopAnimating()
                    let appDelegate = UIApplication.shared.delegate as! AppDelegate
                    //self.user?.getDetails()
                    let authDetails = AWSCognitoIdentityPasswordAuthenticationDetails(username: self.email!, password: self.password!)
                    appDelegate.loginViewController!.passwordAuthenticationCompletion!.set(result: authDetails)
                    
                    print("printing delegate pools current user below, see it it matches what we want")
                    print(AppDelegate.defaultUserPool().currentUser()?.username)
                    print("printing our self.user below")
                    print(self.user)
                    print(self.user?.username)
                    print(self.user?.confirmedStatus)
                    // Return to Login View Controller - this should be handled a bit differently, but added in this manner for simplicity
                }
            }
            return nil
        })
        //(appDelegate.viewController as! ViewController).user = self.user
        //(appDelegate.viewController as! ViewController).userAttributes = self.userAttributes
    }
    
    @objc func inputDidChange(_ sender:AnyObject) {
        if(code.text == nil) {
            self.verifyButton.isEnabled = false
            return
        }
        self.verifyButton.isEnabled = true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    
    /*func fetchUserAttributes() {
        //print("fetching user attributes")
        user = AppDelegate.defaultUserPool().currentUser()
        print(user?.username)
        user?.getDetails().continueOnSuccessWith(block: { (task) -> Any? in
            guard task.result != nil else {
                //print("in this part of fetchuserattributes")
                return nil
            }
           // print("22222in this part of fetchuserattributes")
            self.userAttributes = task.result?.userAttributes
            self.userAttributes?.forEach({ (attribute) in
                print("Name: " + attribute.name!)
                print("Value: " + attribute.value!)
            })
            DispatchQueue.main.async {
                //print("444444in this part of fetchuserattributes")
                //print("fetched attribute values")
            }
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

/*extension VerificationViewController: AWSCognitoIdentityPasswordAuthentication {
    public func getDetails(_ authenticationInput: AWSCognitoIdentityPasswordAuthenticationInput, passwordAuthenticationCompletionSource: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>) {
        //print("here10")
        self.passwordAuthenticationCompletion = passwordAuthenticationCompletionSource
        DispatchQueue.main.async {
            if (self.email == nil || self.email == "") {
                //self.email.text = authenticationInput.lastKnownUsername
                //print("herey")
                print("Broken in verificationview")
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
                print("logging in verification view")
                //AppDelegate.loggedIn = true
                appDelegate.viewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? ViewController
                appDelegate.navigationController?.setViewControllers([appDelegate.viewController!], animated: true)
                    //AppDelegate.loggedIn = true
                }
            }
        }
    }*/
