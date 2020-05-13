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
    var downloaded_index = 0
    var index_for_cache = 0
    var user:AWSCognitoIdentityUser?
    //var userAttributes:[AWSCognitoIdentityProviderAttributeType]?
    var image:UIImage?
    var playerViewController:AVPlayerViewController?
    var user_to_pair_with:String?
    let waitPartnerMemes = DispatchGroup()
    let waitMemesUpdated = DispatchGroup()
    let waitPotentialPartners = DispatchGroup()
    let waitPotentialActivePartner = DispatchGroup()
    let waitFinalPartner = DispatchGroup()
    let waitMemeNamesS3 = DispatchGroup()
    //let waitBackgroundMemes = DispatchGroup()
    let dispatchQueue = DispatchQueue(label: "com.queue.Serial")
    var emitter = CAEmitterLayer()
    var player: AVPlayer?
    var last_recommended_index = -1
    var matches: AWSTask<AWSDynamoDBPaginatedOutput>?
    var found_match = false
    var userAttributes:[AWSCognitoIdentityProviderAttributeType]?
    var activityIndicator = UIActivityIndicatorView()
    var meme_cache = [Data]()
    let meme_cache_semaphore = DispatchSemaphore(value: 0)
    
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var meme: UIImageView!
    
    @IBAction func logout(_ sender: Any) {
        print("here23")
        self.dismiss(animated: true, completion: nil)
        self.user?.signOut()
        print("signed out the user")
        AppDelegate.defaultUserPool().currentUser()?.signOut()
        self.fetchUserAttributes()
    }
    
    
    
    @IBAction func share(_ sender: UIButton) {
        print("inside share")
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        sender.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        UIView.animate(withDuration: 2.0,
                                   delay: 0,
                                   usingSpringWithDamping: CGFloat(0.20),
                                   initialSpringVelocity: CGFloat(6.0),
                                   options: UIView.AnimationOptions.allowUserInteraction,
                                   animations: {
                                    sender.transform = CGAffineTransform.identity
            },
                                   completion: { Void in()  }
        )
        let imageExtensions = ["png", "jpg", "gif", "ifv"]
        let last3 = self.keys[self.index].suffix(3)
        //sender.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        //var share_me:Any?
        if imageExtensions.contains(String(last3)){
            //we've got a gif
            if last3.contains("gif") || last3.contains("ifv"){
                //let gif = UIImage.gifImageWithData(data!)
                var share_me = self.image
                let share_me_container = [share_me] as [Any]
                let activityViewController = UIActivityViewController(activityItems: share_me_container, applicationActivities: nil)
                activityViewController.popoverPresentationController?.sourceView = self.view
                self.present(activityViewController, animated: true, completion: nil)
            }
            else{
                var share_me = self.meme.image
                share_me = UIImage(data: share_me!.jpegData(compressionQuality: 0.1)!)!
                let share_me_container = [share_me] as [Any]
                let activityViewController = UIActivityViewController(activityItems: share_me_container, applicationActivities: nil)
                activityViewController.popoverPresentationController?.sourceView = self.view
                self.present(activityViewController, animated: true, completion: nil)
            }
        }
        else{
            let temp0_url = GetAWSObjectURL().getPreSignedURL(S3DownloadKeyName: self.keys[self.index])
            let temp_url = URL(string: temp0_url)
            let share_me_container = [temp_url] as! [URL]
            let activityViewController = UIActivityViewController(activityItems: share_me_container, applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = self.view
            self.present(activityViewController, animated: true, completion: nil)
        }
        // Reduce image quality substantially through compression
        // Otherwise sharing takes for fucking ever
        // Can change in the future
        // Scale of quality is from 0.0 to 1.0
        /*share_me = UIImage(data: share_me.jpegData(compressionQuality: 0.1)!)!
        //let url = URL(fileURLWithPath: "http://www.google.com")
        let share_me_container = [share_me] as [Any]
        let activityViewController = UIActivityViewController(activityItems: share_me_container, applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.view
        self.present(activityViewController, animated: true, completion: nil)*/
    }
    
    
    @IBAction func back(_ sender: UIButton) {
        if(self.index > 0){
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            sender.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            UIView.animate(withDuration: 2.0,
                                       delay: 0,
                                       usingSpringWithDamping: CGFloat(0.20),
                                       initialSpringVelocity: CGFloat(6.0),
                                       options: UIView.AnimationOptions.allowUserInteraction,
                                       animations: {
                                        sender.transform = CGAffineTransform.identity
                },
                                       completion: { Void in()  }
            )
            self.index = self.index - 2
            self.index_for_cache = self.index_for_cache - 2
            self.loadNextMeme(first: false)
        }
        /*else if (self.index == 1){ // change this eventually
            return
        }*/
        else{
            return
        }
    }
    
    @IBAction func gotogolden(_ sender: UIButton) {
        print("Going to golden set")
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        sender.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        UIView.animate(withDuration: 2.0,
                                   delay: 0,
                                   usingSpringWithDamping: CGFloat(0.20),
                                   initialSpringVelocity: CGFloat(6.0),
                                   options: UIView.AnimationOptions.allowUserInteraction,
                                   animations: {
                                    sender.transform = CGAffineTransform.identity
            },
                                   completion: { Void in()  }
        )
        //sleep(1)
        self.performSegue(withIdentifier: "goldensegue", sender: self)
    }
    
    @objc func sliderValueDidChange(sender:UISlider) {
        if self.last_recommended_index >= self.index{
            self.slider.minimumTrackTintColor = UIColor(red: 0.71, green: 0.44, blue: 0.95, alpha: 1.00)
            self.startSpewing(color: false)
        }
        else if sender.value >= 4.5 {
           self.slider.minimumTrackTintColor = UIColor(red: 0.71, green: 0.44, blue: 0.95, alpha: 1.00)
            // false == purple
            self.startSpewing(color: false)
        } else if sender.value >= 3.5 {
            self.slider.minimumTrackTintColor = UIColor(red: 0.49, green: 0.83, blue: 0.13, alpha: 1.00)
            // true == green
            self.startSpewing(color: true)
         } else if sender.value >= 1.5 {
            self.emitter.removeFromSuperlayer()
            self.slider.minimumTrackTintColor = UIColor(red: 0.97, green: 0.91, blue: 0.11, alpha: 1.00)
         } else {
              self.emitter.removeFromSuperlayer()
              self.slider.minimumTrackTintColor = UIColor(red: 0.82, green: 0.01, blue: 0.11, alpha: 1.00)
         }
    }
    
    @IBOutlet weak var slider: CustomSlider!
    
    @IBAction func next(_ sender: Any) {
        self.slider.isEnabled = false
        
        // This user is active for the first time today
        // Send a notification to Dynamo
        // Adds them to today's Active Users table
        if(self.index == 0){
            var active_user = ActiveUser()
            active_user?.username = user?.username as! NSString
            let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
            let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
            updateMapperConfig.saveBehavior = .updateSkipNullAttributes
            dynamoDBObjectMapper.save(active_user!, configuration: updateMapperConfig).continueWith(block: { (task:AWSTask<AnyObject>!) -> Any? in
                if let error = task.error as NSError? {
                    print("The request failed. Error: \(error)")
                } else {
                    // Do something with task.result or perform other operations.
                }
                return 0
            })
        }
        // vibration indicating we reached the end of the list for today
        if(self.keys.count == self.index+1){
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return
        }
        // vibration indicating success
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // the meme view is hidden because we had a video last time
        // We need to get rid of the AVPlayer used for the video
        // The meme view with either be re-loaded or a video/gif we be loaded
        // inside the loadNextMeme function
        if(self.meme.isHidden){
            self.player?.pause()
            self.player = nil
            self.playerViewController?.willMove(toParent: nil)
            self.playerViewController?.view.removeFromSuperview()
            self.playerViewController?.removeFromParent()
        }
        self.rateCurrentMeme()
        self.loadNextMeme(first: false)
    }
    
    override func viewDidLoad() {
        print("in view did load")
        super.viewDidLoad()
        self.configureSlider()
        //self.callWhenViewing()
    }
    
    //extension CGRect {
    //    var center: CGPoint { return CGPoint(x: midX, y: midY) }
    //}
    
    override func viewWillAppear(_ animated: Bool) {
            //print(AppDelegate.defaultUserPool().currentUser()?.username)
            //sleep(3)
            //print(AppDelegate.defaultUserPool().currentUser()?.username)
            //var midX = self.view.bounds.midX
            //var midY = self.view.bounds.midY
            self.activityIndicator = UIActivityIndicatorView()
        //self.activityIndicator.
            self.activityIndicator.color = UIColor.white
            self.activityIndicator.style = UIActivityIndicatorView.Style.large
            self.activityIndicator.frame = CGRect(x: self.view.bounds.midX - 50, y: self.view.bounds.midY - 100, width: 100, height: 100)
            self.activityIndicator.hidesWhenStopped = true
            self.activityIndicator.layer.zPosition = 1
            view.addSubview(self.activityIndicator)
        
            print("View is appearing viewcontroller")
            super.viewWillAppear(animated)
            //sleep(3)
            print("This is the user in the ViewController " + String((AppDelegate.defaultUserPool().currentUser()?.username!)!))
            print("Their attributes below")
            print(AppDelegate.defaultUserPool().currentUser()?.username)
            self.fetchUserAttributes()
            AppDelegate.loggedIn = true
            //print("Again but the local variable " + String(self.user!.username!))
            //print("Their attributes below")
            //self.fetchUserAttributes()
            //sleep(3)
            
            print("waiting for our meme names")
            print("waiting for our final meme order")
            self.waitMemeNamesS3.enter()
            self.waitMemesUpdated.enter()
            self.loadAllS3MemeNames()
        
            print("Waiting for potential partner")
            print("Waiting for final partner")
            self.waitPotentialPartners.enter()
            self.waitFinalPartner.enter()
            
            self.findPartnerMatchesPart1()
        
            self.waitPotentialPartners.notify(queue: .main){
                print("got into here")
                self.findPartnerMatchesPart2()
                self.waitFinalPartner.notify(queue: .main){
                    print("444444444")
                    if self.found_match{
                        self.loadMemesRecommendedByPartner()
                    }
                    else{
                        let alert = UIAlertController(title: "No Matched User", message: "We could not find a user to match you with :( Your ratings will be immensely helpeful in recommending memes to other users today", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: nil))
                        self.present(alert, animated: true)
                        self.waitMemesUpdated.leave()
                    }
                }
                // THIS GROUP IS DEPENDENT ON QUERY FOUR AND THE BLOCK ABOVE AS WELL
                // 66666666666
                self.waitMemeNamesS3.notify(queue: .main){
                    self.waitMemesUpdated.notify(queue: .main){
                        print("66666666")
                        print("This meme is at the front " + self.keys[0])
                        self.loadNextMeme(first: true)
                    }
                }
            }
    }
    
    /*func callWhenViewing() {
        self.configureSlider()
        self.fetchUserAttributes()
        
        self.waitMemeNamesS3.enter()
        self.waitMemesUpdated.enter()
        self.loadAllS3MemeNames()
    
        self.waitPotentialPartners.enter()
        self.waitFinalPartner.enter()
        
        self.findPartnerMatchesPart1()
    
        self.waitPotentialPartners.notify(queue: .main){
            print("got into here")
            self.findPartnerMatchesPart2()
            self.waitFinalPartner.notify(queue: .main){
                print("444444444")
                if self.found_match{
                    self.loadMemesRecommendedByPartner()
                }
                else{
                    let alert = UIAlertController(title: "No Matched User", message: "We could not find a user to match you with :( Your ratings will be immensely helpeful in recommending memes to other users today", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: nil))
                    self.present(alert, animated: true)
                    self.waitMemesUpdated.leave()
                }
            }
            // THIS GROUP IS DEPENDENT ON QUERY FOUR AND THE BLOCK ABOVE AS WELL
            // 66666666666
            self.waitMemeNamesS3.notify(queue: .main){
                self.waitMemesUpdated.notify(queue: .main){
                    print("66666666")
                    print("This meme is at the front " + self.keys[0])
                    self.loadNextMeme(first: true)
                }
            }
        }
    }*/
    
    func rateCurrentMeme() {
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let meme = Meme()
        print("INDEX INSIDE OF RATECURRENTMEME " + String(self.index))
        print("WE ARE LABELING THE MEME " + self.keys[self.index])
        meme?.username = user?.username as! NSString
        meme?.meme = self.keys[self.index] as NSString
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
    }
    
    func loadNextMeme(first: Bool) {
        //self.meme.isHidden = true
        self.activityIndicator.startAnimating()
        if(!first){
            self.index = self.index + 1
        }
        print("INDEX INSIDE OF LOADNEXTMEME IS " + String(self.index) + " name is " + String(self.keys[self.index]))
        //}
        let transferUtility = AWSS3TransferUtility.default()
        let expression = AWSS3TransferUtilityDownloadExpression()
        if(!(self.downloaded_index > self.index || self.index_for_cache < 0)){
            //print(self.downloaded_index)
            //print(self.index)
            print("our downloaded index " + String(self.downloaded_index) + " is not greater than our normal index " + String(self.index))
            print("or we want back too far and our cache doesn't hold the image anymore")
            print(" our cache index is : " + String(self.index_for_cache))
            transferUtility.downloadData(fromBucket: s3bucket, key: self.keys[self.index], expression: expression) { (task, url, data, error) in
                if error != nil{
                    print(error!)
                    print("error")
                    return
                }
                DispatchQueue.main.sync(execute: {
                    let imageExtensions = ["png", "jpg", "gif", "ifv"]
                    let last3 = self.keys[self.index].suffix(3)
                    if imageExtensions.contains(String(last3)){
                        //we've got a gif
                        if last3.contains("gif") || last3.contains("ifv"){
                            let gif = UIImage.gifImageWithData(data!)
                            self.image = gif
                        }
                        else{
                            let pic = UIImage(data: data!)
                            self.image = pic
                        }
                        self.meme.isHidden = false
                        self.updateUI()
                        self.slider.isEnabled = true
                        self.activityIndicator.stopAnimating()
                        /*if(!first){
                            print("calling background_meme_download from loadNextMeme")
                            self.background_meme_download()
                        }*/
                        self.background_meme_download()
                        return
                    }
                    else{
                        let temp0_url = GetAWSObjectURL().getPreSignedURL(S3DownloadKeyName: self.keys[self.index])
                        let temp_url = URL(string: temp0_url)
                        self.player = AVPlayer(url: temp_url!)
                        self.playerViewController = AVPlayerViewController()
                        self.playerViewController!.player = self.player
                        self.playerViewController!.view.frame = self.meme.frame
                        self.addChild(self.playerViewController!)
                        self.view.addSubview(self.playerViewController!.view)
                        self.playerViewController!.didMove(toParent: self)
                        self.player?.play()
                        self.meme.isHidden = true
                        self.updateUI()
                        self.slider.isEnabled = true
                        self.activityIndicator.stopAnimating()
                        /*if(!first){
                            print("calling background_meme_download from loadNextMeme")
                            self.background_meme_download()
                        }*/
                        self.background_meme_download()
                        return
                    }
                })
            }
        }
        else{
            print("our downloaded index " + String(self.downloaded_index) + " IS greater than our normal index " + String(self.index))
            self.index_for_cache = self.index_for_cache + 1
            let imageExtensions = ["png", "jpg", "gif", "ifv"]
            let last3 = self.keys[self.index].suffix(3)
            print("the meme name at this index is " + self.keys[self.index])
            print("double check this with the file in S3 to make sure we're labeling the right meme")
            if imageExtensions.contains(String(last3)){
                //we've got a gif
                if last3.contains("gif") || last3.contains("ifv"){
                    let gif = UIImage.gifImageWithData(self.meme_cache[index_for_cache])
                    self.image = gif
                }
                else{
                    let pic = UIImage(data: self.meme_cache[index_for_cache])
                    self.image = pic
                }
                self.meme.isHidden = false
                self.updateUI()
                self.slider.isEnabled = true
                self.activityIndicator.stopAnimating()
                return
            }
            else{
                let temp0_url = GetAWSObjectURL().getPreSignedURL(S3DownloadKeyName: self.keys[self.index])
                let temp_url = URL(string: temp0_url)
                self.player = AVPlayer(url: temp_url!)
                self.playerViewController = AVPlayerViewController()
                self.playerViewController!.player = self.player
                self.playerViewController!.view.frame = self.meme.frame
                self.addChild(self.playerViewController!)
                self.view.addSubview(self.playerViewController!.view)
                self.playerViewController!.didMove(toParent: self)
                self.player?.play()
                self.meme.isHidden = true
                self.updateUI()
                self.slider.isEnabled = true
                self.activityIndicator.stopAnimating()
                return
            }
        }
    }
    
    func background_meme_download() {
        self.downloaded_index = index
        self.index_for_cache = 0
        self.meme_cache.removeAll()
        self.dispatchQueue.async{
            let max_10 = self.downloaded_index + 10
            print("here inside background_meme_download")
            print(self.keys.count)
            while (self.downloaded_index < self.keys.count && self.downloaded_index <= max_10){
                //self.waitBackgroundMemes.enter()
                print("in this loop")
                let transferUtility = AWSS3TransferUtility.default()
                let expression = AWSS3TransferUtilityDownloadExpression()
                //print("downloaded index is " + )
                transferUtility.downloadData(fromBucket: self.s3bucket, key: self.keys[self.downloaded_index], expression: expression) { (task, url, data, error) in
                    if error != nil{
                        print(error!)
                        print("error")
                        return
                    }
                    //DispatchQueue.main.sync(execute: {
                        self.meme_cache_semaphore.signal()
                        //self.waitBackgroundMemes.leave()
                        print("leaving the group ")
                        //print("incrementing downloaded index to " + String(self.downloaded_index))
                        self.meme_cache.append(data!)
                        return
                    //})
                }
                self.meme_cache_semaphore.wait()
                self.downloaded_index = self.downloaded_index + 1
                print("incrementing downloaded index to " + String(self.downloaded_index))
            }
        }
        print("end of background_meme_download")
    }
    
    func loadAllS3MemeNames(){
        let s3 = AWSS3.s3(forKey: "defaultKey")
        let listRequest: AWSS3ListObjectsRequest = AWSS3ListObjectsRequest()
        listRequest.bucket = s3bucket
        listRequest.prefix = "actualmemes/"
        s3.listObjects(listRequest).continueWith { (task) -> AnyObject? in
            let listObjectsOutput = task.result;
            for object in (listObjectsOutput?.contents)! {
                self.keys.append(String(object.key!))
                print(String(object.key!))
            }
            //self.meme_cache.count = self.keys.count
            self.waitMemeNamesS3.leave()
            print("We've got our Meme names")
            return nil
        }
    }
    
    // Grab all potential partners
    // These are in the user_matchings DynamoDB table
    func findPartnerMatchesPart1() {
        let queryExpression = AWSDynamoDBQueryExpression()
        queryExpression.keyConditionExpression = "username = :username"
        queryExpression.expressionAttributeValues = [":username": self.user?.username]
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
        updateMapperConfig.saveBehavior = .updateSkipNullAttributes
        self.matches = dynamoDBObjectMapper.query(PartnerMatches.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
        if (task.error != nil){
            print("error")
        }
        if (task.result != nil){
            print("here2")
            self.waitPotentialPartners.leave()
            print("Found potential partner")
        }
        print("here3")
        return task.result
        }) as! AWSTask<AWSDynamoDBPaginatedOutput>
    }
    
    // Find the final partner
    // This is found by finding the closest partner
    // Who is also in the users_active_today DynamoDB table
    func findPartnerMatchesPart2() {
        let matches2 = self.matches?.result?.items
        print("printing out our matches!!!!!!")
        print(matches2)
        let queryExpression = AWSDynamoDBQueryExpression()
        queryExpression.keyConditionExpression = "username = :username"
        queryExpression.expressionAttributeValues = [":username": self.user?.username]
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        if matches2?.count ?? 0 == 1 {
            let user_list = matches2![0] as! PartnerMatches
            let user_list_strings = user_list.getUsers()
            var num_checked_users = 0
            for paired_user in user_list_strings{
                print("in this for loop")
                print("this is the user we are looking for " + paired_user)
                queryExpression.expressionAttributeValues = [":username": paired_user]
                // SECOND QUERY FOR PARTNER WHO WAS ACTIVE
                // 222222222
                self.waitPotentialActivePartner.enter()
                let active_matches = dynamoDBObjectMapper.query(ActiveUser.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
                if (task.error != nil){
                    print("ERROR IN findPartnerMatchesPart2")
                }
                print("calling potentially active partner")
                self.waitPotentialActivePartner.leave()
                return task.result
                }) as! AWSTask<AWSDynamoDBPaginatedOutput>
                print("outside this wait")
                self.waitPotentialActivePartner.notify(queue: .main){
                    // this check hopefully blocks the behavior where
                    // this function is called again despite the first one
                    // returning/leaving the function
                    if(!self.found_match){
                        print("potentially active partner")
                        num_checked_users = num_checked_users + 1
                        let returned_matches = active_matches.result?.items
                        print("printing out returned matches!")
                        print(active_matches)
                        print(returned_matches)
                        if returned_matches?.count ?? 0 == 1 {
                            self.found_match = true
                            self.user_to_pair_with = paired_user
                            print("Found final partner")
                            print("Am I in here twice?")
                            print("exiting waitFinalPartner")
                            self.waitFinalPartner.leave()
                            print("That was the problem")
                            return;
                        }
                            // we need to free the queue even though
                            // we didn't find a match
                        else if num_checked_users == user_list_strings.count{
                            print("exiting waitFinalPartner")
                            self.waitFinalPartner.leave()
                            return;
                        }
                    }
                }
            }
        }
        else { // We didn't have any matches to begin with (need to fill out golden set)
            let alert = UIAlertController(title: "Fill Out the Golden Set!", message: "Click on the treasure chest icon and rate 13 memes in order to get the most out of our recommendation system :)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: nil))
            self.present(alert, animated: true)
        }
    }
    
    func loadMemesRecommendedByPartner() {
        let queryExpression = AWSDynamoDBQueryExpression()
        queryExpression.keyConditionExpression = "username = :username"
        queryExpression.expressionAttributeValues = [":username": self.user_to_pair_with]
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
        updateMapperConfig.saveBehavior = .updateSkipNullAttributes
        var matches5: AWSTask<AWSDynamoDBPaginatedOutput>?
        self.waitPartnerMemes.enter()
        self.dispatchQueue.async{
            // FOURTH QUERY FOR MEME NAMES OF RECOMMENDED MEMES
            matches5 = dynamoDBObjectMapper.query(Meme.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
            if (task.error != nil){
                print("error")
            }
            if (task.result != nil){
                print("here2")
                self.waitPartnerMemes.leave()
            }
            return task.result
            }) as! AWSTask<AWSDynamoDBPaginatedOutput>
        }
        // THIS GROUP IS DEPENDENT ON QUERY FOUR
        // THIS GROUP IS ALSO DEPENDENT ON QUERY 3
        // 555555555
        print("showing current state of self.keys")
        print(self.keys.count)
        // Needs to have the S3 meme names before
        // we alter the ordering
        self.waitMemeNamesS3.notify(queue: .main){
            self.waitPartnerMemes.notify(queue: self.dispatchQueue){
                var all_ratings_of_partner = matches5?.result?.items
                print("our partner has labeled a total of " + String(all_ratings_of_partner!.count) + " memes")
                var temp_keys = [String]()
                for meme_rating_pair in all_ratings_of_partner!{
                    var meme_rating_pair2 = meme_rating_pair as! Meme
                    // We want this rating
                    if(self.keys.contains(meme_rating_pair2.meme as! String)){
                        if(Double(meme_rating_pair2.rating ?? 3) > 4){
                            temp_keys.append(meme_rating_pair2.meme as! String)
                            let index_of_boi = self.keys.firstIndex(of: meme_rating_pair2.meme as! String)
                            self.keys.remove(at: index_of_boi!)
                        }
                        else if(Double(meme_rating_pair2.rating ?? 3) < 2){
                            let index_of_boi = self.keys.firstIndex(of: meme_rating_pair2.meme as! String)!
                            self.keys.remove(at: index_of_boi)
                        }
                    }
                }
                print("We should have " + String(temp_keys.count) + " memes shifted to the front")
                self.last_recommended_index = temp_keys.count
                for keyster in self.keys{
                    temp_keys.append(keyster)
                }
                self.keys = temp_keys
                print("This meme should be at the front " + self.keys[0])
                print("We've got our final meme order")
                self.waitMemesUpdated.leave()
            }
        }
    }
    
    func fetchUserAttributes() {
        print("inside viewdidLoad fetchuserattributes")
        user = AppDelegate.defaultUserPool().currentUser()
        user?.getDetails().continueOnSuccessWith(block: { (task) -> Any? in
            guard task.result != nil else {
                print("fetchuserattributes failed in viewdidload")
                return nil
            }
            print("fetchuserattributes worked in viewdidload")
            self.userAttributes = task.result?.userAttributes
            self.userAttributes?.forEach({ (attribute) in
                print("Name: " + attribute.name!)
                print("Value: " + attribute.value!)
            })
            DispatchQueue.main.async {
                print("fetchuserattributes worked in viewdidload")
            }
            return nil
        })
    }
    
    func configureSlider() {
        self.slider.isContinuous = false
        self.slider.minimumValue = 0
        self.slider.maximumValue = 5
        self.slider.addTarget(self, action:#selector(sliderValueDidChange(sender:)), for: .allEvents)
    }
    
    func updateUI() {
        meme.image = image
    }
    
    func startSpewing(color: Bool) {
        let trackRect =  self.slider.trackRect(forBounds: self.slider.bounds)
        let thumbRect = self.slider.thumbRect(forBounds: self.slider.bounds, trackRect: trackRect, value: self.slider.value)
        self.emitter.emitterPosition = CGPoint(x: thumbRect.origin.x + self.slider.frame.origin.x - 80, y: self.slider.frame.origin.y + 28)
        self.emitter.emitterShape = CAEmitterLayerEmitterShape.line
        self.emitter.emitterSize = CGSize(width: 70.0, height: 2.0)
        self.emitter.emitterCells = generateEmitterCells(color: color)
        self.view.layer.addSublayer(emitter)
    }
    
    func generateEmitterCells(color: Bool) -> [CAEmitterCell] {
    var cells:[CAEmitterCell] = [CAEmitterCell]()
        var x = 0
        while x < 20{
            let cell = CAEmitterCell()
            cell.birthRate = 4.0
            cell.lifetime = 1.0
            cell.lifetimeRange = 0
            cell.velocity = getRandomNumber()
            cell.velocityRange = getRandomNumber() + 5
            cell.emissionLongitude = getRandomNumber()
            cell.emissionLatitude = getRandomNumber()
            cell.emissionRange = 0.5
            cell.spin = 3.5
            cell.spinRange = 0
            if(color){
                cell.contents = UIImage(named: "greencircle")?.cgImage
            }
            else{
                cell.contents = UIImage(named: "purplecircle")?.cgImage
            }
            cell.scaleRange = 0.25
            cell.scale = 0.1
            cells.append(cell)
            x = x + 1
        }
        return cells
    }
    
    func getRandomNumber() -> CGFloat {
        return CGFloat(arc4random_uniform(100))
    }
}

