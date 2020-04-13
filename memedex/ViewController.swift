//
//  InitialViewController.swift
//  memedex
//
//  Created by meagh054 on 2/12/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import AWSS3
import AWSCognito
import AWSCognitoIdentityProvider
import AWSCore
import AWSDynamoDB

class ViewController: UIViewController {
    
    
    
    let s3bucket = "memedexbucket"
    var keys = [String]()
    var index = 1
    var user:AWSCognitoIdentityUser?
    var userAttributes:[AWSCognitoIdentityProviderAttributeType]?
    
    @IBOutlet weak var meme: UIImageView!
    
    @IBAction func logout(_ sender: Any) {
        print("here23")
        user?.signOut()
        self.fetchUserAttributes()
    
    }
    
    @IBOutlet weak var slider: UISlider!
    
    @IBAction func next(_ sender: Any) {
        if(self.keys.count == index){
            print("End of list")
            return
        }
        //print(self.keys[index])
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let meme = Meme()
        meme?.meme = self.keys[index]
        meme?.rating = slider.value as NSNumber
        let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
        updateMapperConfig.saveBehavior = .updateSkipNullAttributes
        dynamoDBObjectMapper.save(meme!, configuration: updateMapperConfig).continueWith(block: { (task:AWSTask<AnyObject>!) -> Any? in
            if let error = task.error as? NSError {
                print("The request failed. Error: \(error)")
            } else {
                // Do something with task.result or perform other operations.
            }
            return 0
        })
        
        let transferUtility = AWSS3TransferUtility.default()
        let expression = AWSS3TransferUtilityDownloadExpression()
        transferUtility.downloadData(fromBucket: s3bucket, key: self.keys[index], expression: expression) { (task, url, data, error) in
            print("grabbing image from S3")
            if error != nil{
                print(error!)
                print("error")
                return
            }
            DispatchQueue.main.async(execute: {
                self.image = UIImage(data: data!)!
            })
        }
        index = index + 1
    }
    
    var image = UIImage(){
        didSet{
            updateUI()
        }
    }
    
    override func viewDidLoad() {
        print("view controller view did load")
        super.viewDidLoad()
        slider.isContinuous = false
        slider.minimumValue = 0
        slider.maximumValue = 5
        // printing off objects, might have to change key
        let s3 = AWSS3.s3(forKey: "defaultKey")
        let listRequest: AWSS3ListObjectsRequest = AWSS3ListObjectsRequest()
        listRequest.bucket = s3bucket
        s3.listObjects(listRequest).continueWith { (task) -> AnyObject? in
            let listObjectsOutput = task.result;
            for object in (listObjectsOutput?.contents)! {
                self.keys.append(String(object.key!))
                print(String(object.key!))
            }
            return nil
        }
        sleep(5)
        //self.keys.remove(at: 0)
        //AppDelegate.setupCognitoUserPool()
        //AppDelegate.checkLogin()
        //let boofy = (self.storyboard?.instantiateViewController(withIdentifier: "LoginViewController"))!
        //self.present(boofy, animated: true, completion: nil)
        //self.resetAttributeValues()
        self.fetchUserAttributes()
        /*
        Print off image names
         for key in self.keys{
            print(key)
        }
        */
        return
    }
    
    func fetchUserAttributes() {
        print("here19")
        //self.resetAttributeValues()
        user = AppDelegate.defaultUserPool().currentUser()
        user?.getDetails().continueOnSuccessWith(block: { (task) -> Any? in
            guard task.result != nil else {
                return nil
            }
            self.userAttributes = task.result?.userAttributes
            self.userAttributes?.forEach({ (attribute) in
                print("Name: " + attribute.name!)
            })
            DispatchQueue.main.async {
                //self.setAttributeValues()
                print("fetched attribute values")
            }
            return nil
        })
    }
    
    func updateUI() {
        meme.image = image
    }
}
