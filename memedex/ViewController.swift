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
import AVKit
import AVFoundation

class ViewController: UIViewController {
    
    
    
    let s3bucket = "memedexbucket"
    var keys = [String]()
    var index = 0
    var user:AWSCognitoIdentityUser?
    var userAttributes:[AWSCognitoIdentityProviderAttributeType]?
    var image:UIImage?
    var playerViewController:AVPlayerViewController?
    
    @IBOutlet weak var meme: UIImageView!
    
    @IBAction func logout(_ sender: Any) {
        print("here23")
        user?.signOut()
        self.fetchUserAttributes()
    
    }
    
    @IBOutlet weak var slider: UISlider!
    
    @IBAction func next(_ sender: Any) {
        print("printing index below")
        print(self.index)
        print("printing number of keys below")
        print(self.keys.count)
        print("printing all keys")
        if(self.keys.count == index){
            print("End of list")
            return
        }
        // the meme view is hidden because we had a video last time
        // We need to get rid of the AVPlayer used last time
        // Whether or not we initialize another AVPlayer
        if(self.meme.isHidden){
            print("meme was hidden")
            self.playerViewController?.willMove(toParent: nil)
            self.playerViewController?.view.removeFromSuperview()
            self.playerViewController?.removeFromParent()
        }
        //print(self.keys[index])
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let meme = Meme()
        meme?.meme = self.keys[index]
        meme?.rating = slider.value as NSNumber
        let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
        updateMapperConfig.saveBehavior = .updateSkipNullAttributes
        dynamoDBObjectMapper.save(meme!, configuration: updateMapperConfig).continueWith(block: { (task:AWSTask<AnyObject>!) -> Any? in
            if let error = task.error as NSError? {
                print("The request failed. Error: \(error)")
            } else {
                // Do something with task.result or perform other operations.
            }
            return 0
        })
        
        let transferUtility = AWSS3TransferUtility.default()
        let expression = AWSS3TransferUtilityDownloadExpression()
        //let url: URL? = URL(string: self.keys[self.index])
        transferUtility.downloadData(fromBucket: s3bucket, key: self.keys[self.index], expression: expression) { (task, url, data, error) in
            print("grabbing image from S3")
            print("printing current index")
            //print(self.index)
            //print(self.keys[self.index])
            //print("wtf is goin on")
            if error != nil{
                print(error!)
                print("error")
                return
            }
            DispatchQueue.main.sync(execute: {
                let imageExtensions = ["png", "jpg", "gif"]
                let last3 = self.keys[self.index].suffix(3)
                if imageExtensions.contains(String(last3)){
                    let test = UIImage(data: data!)
                    self.image = test
                    self.meme.isHidden = false
                    self.updateUI()
                    self.index = self.index + 1
                    return
                }
                else{
                    print("This is a video")
                    let temp0_url = GetAWSObjectURL().getPreSignedURL(S3DownloadKeyName: self.keys[self.index])
                    print("url of object below (hopefully)")
                    print(temp0_url)
                    let temp_url = URL(string: temp0_url)
                    let player = AVPlayer(url: temp_url!)
                    self.playerViewController = AVPlayerViewController()
                    self.playerViewController!.player = player
                    self.playerViewController!.view.frame = self.meme.frame
                    //self.view.addSubview(playerViewController)
                    //let player_frame = self.meme.frame
                    //let videoPlayerView = VideoPlayerView(frame: player_frame)
                    //videoPlayerView.player = player
                    self.addChild(self.playerViewController!)
                    self.view.addSubview(self.playerViewController!.view)
                    self.playerViewController!.didMove(toParent: self)
                    player.play()
                    self.meme.isHidden = true
                    print("hiding meme")
                    /*self.present(playerViewController, animated: true){
                        playerViewController.player!.play()
                    }*/
                    self.updateUI()
                    self.index = self.index + 1
                    return
                }
            })
        }
        //self.index = self.index + 1
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    
    /*var image = UIImage(){
        didSet{
            updateUI()
        }
    }*/
    
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
