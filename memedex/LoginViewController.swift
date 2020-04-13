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

    
    
    @IBOutlet weak var email: UITextField!
    
    @IBOutlet weak var password: UITextField!
    
    @IBOutlet weak var loginButton: UIButton!
    
    var user: AWSCognitoIdentityUser?
    
    var cognitoConfig:CognitoConfig?
    
    
    var passwordAuthenticationCompletion: AWSTaskCompletionSource<AWSCognitoIdentityPasswordAuthenticationDetails>?
    
    override func viewWillAppear(_ animated: Bool) {
        print("here7")
        super.viewWillAppear(animated)
        self.password?.addTarget(self, action: #selector(inputDidChange(_:)), for: .editingChanged)
        self.email?.addTarget(self, action: #selector(inputDidChange(_:)), for: .editingChanged)
        self.cognitoConfig = CognitoConfig()
        self.password.delegate = self
        self.email.delegate = self
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
        
    }
    
    @IBAction func login(_ sender: Any) {
        print("here8")
        if (self.email?.text != nil && self.password?.text != nil) {
            print("here8.2")
            let authDetails = AWSCognitoIdentityPasswordAuthenticationDetails(username: self.email!.text!, password: self.password!.text! )
            print("here8.3")
            self.passwordAuthenticationCompletion?.set(result: authDetails)
            print("here8.4")
        }
    }
    
    
    @IBOutlet weak var signup_button: UIButton!
    @IBAction func signup(_ sender: Any) {
        //let staticCredentialProvider = AWSStaticCredentialsProvider.init(accessKey: self.cognitoConfig!.getClientId(), secretKey: self.cognitoConfig!.getClientSecret())
        
        //let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.USEast2,
        //let configuration = AWSServiceConfiguration.init(region:.USEast2, credentialsProvider:staticCredentialProvider)
        //AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        let email = AWSCognitoIdentityUserAttributeType()
        //let password = AWSCognitoIdentityUserAttributeType()
        let name = AWSCognitoIdentityUserAttributeType()
        email!.value = self.email.text
        email!.name = "email"
        //password!.value = self.password.text
        //password!.name = "password"
        //name!.value = self.email.text
        //name!.name = "username"
        print(AppDelegate.pool)
        AppDelegate.pool?.signUp(self.email.text!, password: self.password.text!, userAttributes: [email!], validationData: nil).continueWith{ (response) -> Any? in
            if response.error != nil {
                let alert = UIAlertController(title: "Error", message: (response.error! as NSError).userInfo["message"] as? String, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler:nil))
                self.present(alert, animated: true, completion: nil)
            }
            else{
                //let response = task.result!
                print("here")
                self.user = response.result?.user
                print("herey")
                print(response)
                DispatchQueue.main.async {
                    //self.codeDeliveryDetails = response.result?.codeDeliveryDetails
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
        print("here9")
        if (self.email?.text != nil && self.password?.text?.count ?? 0 > 7) {
            self.loginButton?.isEnabled = true
            self.signup_button?.isEnabled = true
        } else {
            self.loginButton?.isEnabled = false
            self.signup_button?.isEnabled = false
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    

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
        print("here10")
        self.passwordAuthenticationCompletion = passwordAuthenticationCompletionSource
        DispatchQueue.main.async {
            if (self.email.text == nil) {
                //self.email.text = authenticationInput.lastKnownUsername
                print("herey")
            }
        }
    }
    
    public func didCompleteStepWithError(_ error: Error?) {
        DispatchQueue.main.async {
            print("here11")
            if let error = error as NSError? {
                print("here11.1")
                let alertController = UIAlertController(title: error.userInfo["__type"] as? String,
                                                        message: error.userInfo["message"] as? String,
                                                        preferredStyle: .alert)
                let retryAction = UIAlertAction(title: "Retry", style: .default, handler: nil)
                alertController.addAction(retryAction)
                
                self.present(alertController, animated: true, completion:  nil)
            } else {
                print("here11.2")
                self.dismiss(animated: true, completion: {
                    self.email.text = nil
                    self.password.text = nil
                })
            }
        }
    }
}
