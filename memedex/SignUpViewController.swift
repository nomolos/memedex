//
//  SignUpViewController.swift
//  memedex
//
//  Created by meagh054 on 5/26/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import AWSCognito
import AWSCognitoIdentityProvider

class SignUpViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var email: TextField!
    
    @IBOutlet weak var password: TextField!
    
    @IBOutlet weak var confirm_password: TextField!
    
    @IBOutlet weak var signup_requirements: UILabel!
    
    var user: AWSCognitoIdentityUser?
    
    var userAttributes:[AWSCognitoIdentityProviderAttributeType]?
    
    var activityIndicator = UIActivityIndicatorView()
    
    @IBOutlet weak var signup_button: UIButton!
    
    override func viewWillAppear(_ animated: Bool) {
        self.email.delegate = self
        self.password.delegate = self
        self.confirm_password.delegate = self
        if (self.password?.text?.count ?? 0 > 7) {
            self.signup_button?.isEnabled = true
            self.signup_requirements.isHidden = true
        } else {
            self.signup_button?.isEnabled = false
            self.signup_requirements.isHidden = false
        }
        self.activityIndicator = UIActivityIndicatorView()
        //self.activityIndicator.
        self.activityIndicator.color = UIColor.gray
        self.activityIndicator.style = UIActivityIndicatorView.Style.large
        self.activityIndicator.frame = CGRect(x: self.view.bounds.midX - 50, y: self.view.bounds.midY - 100, width: 100, height: 100)
        self.activityIndicator.hidesWhenStopped = true
        self.activityIndicator.layer.zPosition = 1
        view.addSubview(self.activityIndicator)
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
        self.password?.addTarget(self, action: #selector(self.inputDidChange(_:)), for: .editingChanged)
        self.confirm_password?.addTarget(self, action: #selector(self.inputDidChange(_:)), for: .editingChanged)
        self.email?.addTarget(self, action: #selector(self.inputDidChange(_:)), for: .editingChanged)
    }
    

    @IBAction func signup(_ sender: Any) {
        self.activityIndicator.startAnimating()
        let email = AWSCognitoIdentityUserAttributeType()
        let name = AWSCognitoIdentityUserAttributeType()
        email!.value = self.email.text
        email!.name = "email"
        AppDelegate.pool?.signUp(self.email.text!, password: self.password.text!, userAttributes: [email!], validationData: nil).continueWith{ (response) -> Any? in
            if response.error != nil {
                print(response.error)
                let alert = UIAlertController(title: "Error", message: (response.error! as NSError).userInfo["message"] as? String, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler:nil))
                self.present(alert, animated: true, completion: nil)
            }
            else{
                print("INSIDE OF SIGNUPVIEW LOOKING AT SIGNUP STUFF")
                print(response.result)
                print(response.result?.user)
                print(response.result?.userSub)
                print(self.user)
                print(AppDelegate.pool?.currentUser())
                print(AppDelegate.pool?.getUser())
                self.user = response.result?.user
                print("About to perform segue to verification view controller")
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.performSegue(withIdentifier: "VerifySegue2", sender: self)
                }
            }
            return 1
        }
    }
    
    @objc func inputDidChange(_ sender:AnyObject) {
        if (self.email?.text != nil && self.password?.text?.count ?? 0 > 7) {
            self.signup_button?.isEnabled = true
            self.signup_requirements.isHidden = true
        } else {
            self.signup_requirements.isHidden = false
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("in text field should return")
        self.view.endEditing(true)
        return false
    }
    
    @objc func dismissKeyboard() {
        print("in dismiss keyboard")
        self.view.endEditing(true)
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let verificationController = segue.destination as! VerificationViewController
        verificationController.isModalInPresentation = true
        verificationController.user = self.user!
        verificationController.email = self.email.text
        verificationController.password = self.password.text
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
