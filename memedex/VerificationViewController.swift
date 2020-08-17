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
        self.activityIndicator.color = UIColor.gray
        self.activityIndicator.style = UIActivityIndicatorView.Style.large
        self.activityIndicator.frame = CGRect(x: self.view.bounds.midX - 50, y: self.view.bounds.midY - 100, width: 100, height: 100)
        self.activityIndicator.hidesWhenStopped = true
        self.activityIndicator.layer.zPosition = 1
        view.addSubview(self.activityIndicator)
        self.code.addTarget(self, action: #selector(inputDidChange(_:)), for: .editingChanged)
        self.code.delegate = self
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.verificationViewController = self
    }
    
    @IBAction func verify(_ sender: Any) {
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
                    self.activityIndicator.stopAnimating()
                    let appDelegate = UIApplication.shared.delegate as! AppDelegate
                    let authDetails = AWSCognitoIdentityPasswordAuthenticationDetails(username: self.email!, password: self.password!)
                    appDelegate.loginViewController!.passwordAuthenticationCompletion!.set(result: authDetails)
                }
            }
            return nil
        })
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

}
