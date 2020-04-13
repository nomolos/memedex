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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.code.addTarget(self, action: #selector(inputDidChange(_:)), for: .editingChanged)
        self.code.delegate = self

        // Do any additional setup after loading the view.
    }
    
    @IBAction func verify(_ sender: Any) {
        print("attempting to verify")
        self.user?.confirmSignUp(code.text!)
        .continueWith(block: { (response) -> Any? in
            if response.error != nil {
                DispatchQueue.main.async {
                    print("verifying didn't work")
                    self.code.text = ""
                    let alert = UIAlertController(title: "Error", message: "Code don't work bruh", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Retry", style: .default, handler: nil))
                    self.present(alert, animated: true, completion:nil)
                }
            } else {
                DispatchQueue.main.async {
                    print("verifying did work")
                    // Return to Login View Controller - this should be handled a bit differently, but added in this manner for simplicity
                    self.presentingViewController?.presentingViewController?.dismiss(animated: true, completion: nil)
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
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
