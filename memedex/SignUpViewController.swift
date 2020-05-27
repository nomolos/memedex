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
        if((self.email.text?.isValidEmail())! && self.password.text?.count ?? 0 > 7 && self.password.text == self.confirm_password.text){
            AppDelegate.pool?.signUp(self.email.text!, password: self.password.text!, userAttributes: [email!], validationData: nil).continueWith{ (response) -> Any? in
                if response.error != nil {
                    let casted = response.error as! NSError
                    if((casted.userInfo["__type"] as! String) == "UsernameExistsException"){
                        DispatchQueue.main.async {
                            self.activityIndicator.stopAnimating()
                            self.performSegue(withIdentifier: "VerifySegue2", sender: self)
                        }
                    }
                    else{
                        print("This exception is not a signup duplicate exception")
                        print(response.error)
                    }
                }
                else{
                    self.user = response.result?.user
                    DispatchQueue.main.async {
                        self.activityIndicator.stopAnimating()
                        self.performSegue(withIdentifier: "VerifySegue2", sender: self)
                    }
                }
                return 1
            }
            self.performSegue(withIdentifier: "VerifySegue2", sender: self)
        }
        if(!(self.email.text?.isValidEmail())!){
            self.activityIndicator.stopAnimating()
            let alert = UIAlertController(title: "Invalid Email", message: "The email address entered is invalid", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Retry", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
        else if(self.password.text?.count ?? 0 < 8){
            self.activityIndicator.stopAnimating()
            let alert = UIAlertController(title: "Password too short", message: "Password needs to be at least 8 characters", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Retry", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
        else if(!(self.password.text == self.confirm_password.text)){
            self.activityIndicator.stopAnimating()
            let alert = UIAlertController(title: "Passwords don't match", message: "Try typing your password in again", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Retry", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
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

extension String {
    func isValidEmail() -> Bool {
        guard !self.lowercased().hasPrefix("mailto:") else { return false }
        guard let emailDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return false }
        let matches = emailDetector.matches(in: self, options: NSRegularExpression.MatchingOptions.anchored, range: NSRange(location: 0, length: self.count))
        guard matches.count == 1 else { return false }
        return matches[0].url?.scheme == "mailto"
    }
}
