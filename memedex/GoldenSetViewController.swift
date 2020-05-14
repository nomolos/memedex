//
//  GoldenSetViewController.swift
//  memedex
//
//  Created by meagh054 on 4/22/20.
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
import Foundation

class GoldenSetViewController: UIViewController {

    
    var user:AWSCognitoIdentityUser?
    var userAttributes:[AWSCognitoIdentityProviderAttributeType]?
    var playerViewController:AVPlayerViewController?
    var keys = [String]()
    var index = 1
    let s3bucket = "memedexbucket"
    var image:UIImage?
    let waitPotentialPartners = DispatchGroup()
    var emitter = CAEmitterLayer()
    var activityIndicator = UIActivityIndicatorView()
    var meme_cache = [Data]()
    let meme_cache_semaphore = DispatchSemaphore(value: 0)
    let dispatchQueue = DispatchQueue(label: "com.queue.Serial")
    
    let waitMemeNames = DispatchGroup()
    
    
    @IBOutlet weak var slider: CustomSlider!
    
    @IBOutlet weak var meme: UIImageView!
    
    @IBAction func next(_ sender: Any) {
        self.slider.isEnabled = false
        //vibration indicating success
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        // the meme view is hidden because we had a video last time
        // We need to get rid of the AVPlayer used last time
        // Whether or not we initialize another AVPlayer
        if(self.meme.isHidden){
            self.playerViewController?.willMove(toParent: nil)
            self.playerViewController?.view.removeFromSuperview()
            self.playerViewController?.removeFromParent()
        }
        
        
        // previous meme being rated
        var dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let meme = GoldenMeme()
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
        
        // load the next meme
        self.index = self.index + 1
        
        // WE HAVE FINISHED LABELING THE GOLDEN SET
        // TIME TO FIND OUR MATCHES AND UPLOAD THEM TO DYNAMO
        if(self.keys.count == index){
            //vibration indicating failure to go forward
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            var dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
            let scanExpression = AWSDynamoDBScanExpression()
            let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
            updateMapperConfig.saveBehavior = .updateSkipNullAttributes
            //scanExpression.limit = 50
            dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
            var json_response = dynamoDBObjectMapper.scan(GoldenMeme.self, expression: scanExpression, configuration: updateMapperConfig)
            //print(json_response)
            sleep(2)
            
            var user_ratings = [String:Double]()
            var user_distances = [String:Double]()
            var user_memecount = [String:Int]()
            
            
            // find our ratings and initialize a dictionary with them
            for item in json_response.result!.items{
                let goldy = item as! GoldenMeme
                let username = goldy.username as! String
                let memename = goldy.meme as! String
                let rating = goldy.rating as! Double
                // print(String((self.user?.username)!))
                print("\n")
                print(username)
                print(memename)
                print(rating)
                print("\n")
                if(username==self.user?.username!){
                    user_ratings[memename] = rating
                }
                // inefficient but makes sure that our user distance values are initialized
                else{
                    user_distances[username] = 0
                    user_memecount[username] = 0
                }
            }
            
            // For every item
            // If it's not ours, get the difference in rating between it and our rating for the same meme
            // Add this distance to its corresponding user
            // We want to find the user with the smallest distance
            for item in json_response.result!.items{
                let goldy = item as! GoldenMeme
                let username = goldy.username as! String
                let memename = goldy.meme as! String
                let rating = goldy.rating as! Double
                if(username != self.user?.username!){
                    var sum = user_ratings[memename]! - rating
                    sum = sum*sum
                    user_distances[username]! += sum
                    user_memecount[username]! += 1
                }
            }
            
            // People who don't complete the set won't be matched
            // Since their "distances" will be artificially low
            for user_2 in user_memecount{
                // this user did not label all 13 memes :(
                // Give them an artificially high score so we don't get paired
                if user_2.1 != 13{
                    // print("disqualifying " + user_2.0 + " because they labeled only " + String(user_2.1) + " memes in the golden set")
                    user_distances.removeValue(forKey: user_2.0)
                }
            }
            
            // sort user_distances in ascending order
            // the lower the distance the stronger the match
            // Add this to the users 'matches' table
            let byValue = {
                (elem1:(key: String, val: Double), elem2:(key: String, val: Double))->Bool in
                if elem1.val < elem2.val {
                    return true
                } else {
                    return false
                }
            }
            let sorted_distances = user_distances.sorted(by: byValue)
            let partner_matches = PartnerMatches()
            partner_matches?.setUsers(users: sorted_distances)
            partner_matches?.username = user?.username as! NSString
            self.waitPotentialPartners.enter()
            dynamoDBObjectMapper.save(partner_matches!, configuration: updateMapperConfig).continueWith(block: { (task:AWSTask<AnyObject>!) -> Any? in
                if let error = task.error as NSError? {
                    print("The request failed. Error: \(error)")
                } else {
                    // Do something with task.result or perform other operations.
                }
                self.waitPotentialPartners.leave()
                return 0
            })
            self.waitPotentialPartners.notify(queue: .main){
                print("leaving golden set")
                let alert = UIAlertController(title: "All Set!", message: "Thank you for labeling the golden set! We now have the necessary data to recommend memes to you.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: {(alert: UIAlertAction!) in //self.navigationController?.popViewController(animated: true);
                //self.dismiss(animated: true, completion: nil);
                let appDelegate = UIApplication.shared.delegate as! AppDelegate
                appDelegate.viewController = nil
                appDelegate.viewController = self.storyboard?.instantiateViewController(withIdentifier: "ViewController") as? ViewController
                appDelegate.navigationController?.setViewControllers([appDelegate.viewController!], animated: true)
                }))
                self.present(alert, animated: true)
                return
            }
        }
        
        // We haven't reached the end of the golden set yet
        // Load up a new meme
        else{
            print("we have this many memes in our cache " + String(self.meme_cache.count))
            print("This is our current index " + String(self.index))
            if(!(self.meme_cache.count > self.index-1)){
                self.activityIndicator.startAnimating()
                let transferUtility = AWSS3TransferUtility.default()
                let expression = AWSS3TransferUtilityDownloadExpression()
                transferUtility.downloadData(fromBucket: s3bucket, key: self.keys[self.index], expression: expression) { (task, url, data, error) in
                    if error != nil{
                        print(error!)
                        print("error")
                        return
                    }
                    DispatchQueue.main.sync(execute: {
                        let imageExtensions = ["png", "jpg", "gif", "ifv", "PNG", "JPG", "GIF", "IFV"]
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
                            return
                        }
                        else{
                            let temp0_url = GetAWSObjectURL().getPreSignedURL(S3DownloadKeyName: self.keys[self.index])
                            let temp_url = URL(string: temp0_url)
                            let player = AVPlayer(url: temp_url!)
                            self.playerViewController = AVPlayerViewController()
                            self.playerViewController!.player = player
                            self.playerViewController!.view.frame = self.meme.frame
                            self.addChild(self.playerViewController!)
                            self.view.addSubview(self.playerViewController!.view)
                            self.playerViewController!.didMove(toParent: self)
                            player.play()
                            self.meme.isHidden = true
                            self.updateUI()
                            self.slider.isEnabled = true
                            self.activityIndicator.stopAnimating()
                            return
                        }
                    })
                }
            }
            else{
                self.activityIndicator.startAnimating()
                //DispatchQueue.main.sync(execute: {
                    let imageExtensions = ["png", "jpg", "gif", "ifv", "PNG", "JPG", "GIF", "IFV"]
                    let last3 = self.keys[self.index].suffix(3)
                    if imageExtensions.contains(String(last3)){
                        //we've got a gif
                        if last3.contains("gif") || last3.contains("ifv"){
                            let gif = UIImage.gifImageWithData(self.meme_cache[self.index-1])
                            self.image = gif
                        }
                        else{
                            let pic = UIImage(data: self.meme_cache[self.index-1])
                            self.image = pic
                        }
                        self.meme.isHidden = false
                        self.updateUI()
                        self.slider.isEnabled = true
                        self.activityIndicator.stopAnimating()
                        return
                    }
                    else{
                        let temp0_url = GetAWSObjectURL().getPreSignedURL(S3DownloadKeyName: self.keys[self.index-1])
                        let temp_url = URL(string: temp0_url)
                        let player = AVPlayer(url: temp_url!)
                        self.playerViewController = AVPlayerViewController()
                        self.playerViewController!.player = player
                        self.playerViewController!.view.frame = self.meme.frame
                        self.addChild(self.playerViewController!)
                        self.view.addSubview(self.playerViewController!.view)
                        self.playerViewController!.didMove(toParent: self)
                        player.play()
                        self.meme.isHidden = true
                        self.updateUI()
                        self.slider.isEnabled = true
                        self.activityIndicator.stopAnimating()
                        return
                    }
                //})
            }
        }
    }
    
    override func viewDidLoad() {
        print("golden set view controller view did load")
        super.viewDidLoad()
        slider.isContinuous = false
        slider.minimumValue = 0
        slider.maximumValue = 5
        slider.addTarget(self, action:#selector(sliderValueDidChange(sender:)), for: .allEvents)
        let alert = UIAlertController(title: "Recommendation Engine", message: "Give ratings to these 13 memes to help us better recommend memes to you in the future. You can always come back and re-do this at a later time.", preferredStyle: .alert)
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
        super.viewDidLoad()
        self.waitMemeNames.enter()
        let s3 = AWSS3.s3(forKey: "defaultKey")
        let listRequest: AWSS3ListObjectsRequest = AWSS3ListObjectsRequest()
        listRequest.bucket = s3bucket
        listRequest.prefix = "goldenset/"
        s3.listObjects(listRequest).continueWith { (task) -> AnyObject? in
            let listObjectsOutput = task.result;
            for object in (listObjectsOutput?.contents)! {
                self.keys.append(String(object.key!))
                print(String(object.key!))
            }
            self.waitMemeNames.leave()
            return nil
        }
        self.fetchUserAttributes()
        self.activityIndicator.startAnimating()
        // Go ahead and load first item
        self.waitMemeNames.notify(queue: .main){
            let transferUtility = AWSS3TransferUtility.default()
            let expression = AWSS3TransferUtilityDownloadExpression()
            transferUtility.downloadData(fromBucket: self.s3bucket, key: self.keys[self.index], expression: expression) { (task, url, data, error) in
                if error != nil{
                    print(error!)
                    print("error")
                    return
                }
                DispatchQueue.main.sync(execute: {
                    let imageExtensions = ["png", "jpg", "gif", "ifv", "PNG", "JPG", "GIF", "IFV"]
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
                        return
                    }
                    else{
                        let temp0_url = GetAWSObjectURL().getPreSignedURL(S3DownloadKeyName: self.keys[self.index])
                        let temp_url = URL(string: temp0_url)
                        let player = AVPlayer(url: temp_url!)
                        self.playerViewController = AVPlayerViewController()
                        self.playerViewController!.player = player
                        self.playerViewController!.view.frame = self.meme.frame
                        self.addChild(self.playerViewController!)
                        self.view.addSubview(self.playerViewController!.view)
                        self.playerViewController!.didMove(toParent: self)
                        player.play()
                        self.meme.isHidden = true
                        self.updateUI()
                        self.slider.isEnabled = true
                        self.activityIndicator.stopAnimating()
                        return
                    }
                })
            }
            self.background_meme_download()
        }
    }
    
    @objc func sliderValueDidChange(sender:UISlider) {
        if sender.value >= 4.5 {
           self.slider.minimumTrackTintColor = UIColor(red: 0.71, green: 0.44, blue: 0.95, alpha: 1.00)
           self.startSpewing(color: false)
        } else if sender.value >= 3.5 {
            self.slider.minimumTrackTintColor = UIColor(red: 0.49, green: 0.83, blue: 0.13, alpha: 1.00)
            self.startSpewing(color: true)
         } else if sender.value >= 1.5 {
            self.emitter.removeFromSuperlayer()
            self.slider.minimumTrackTintColor = UIColor(red: 0.97, green: 0.91, blue: 0.11, alpha: 1.00)
         } else {
              self.emitter.removeFromSuperlayer()
              self.slider.minimumTrackTintColor = UIColor(red: 0.82, green: 0.01, blue: 0.11, alpha: 1.00)
         }
    }
    
    func fetchUserAttributes() {
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
                print("fetched attribute values")
            }
            return nil
        })
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
    
    func background_meme_download() {
        self.meme_cache.removeAll()
        self.dispatchQueue.async{
            print("here inside background_meme_download")
            print(self.keys.count)
            var temp = 1
            while (temp < 13){
                let transferUtility = AWSS3TransferUtility.default()
                let expression = AWSS3TransferUtilityDownloadExpression()
                transferUtility.downloadData(fromBucket: self.s3bucket, key: self.keys[temp], expression: expression) { (task, url, data, error) in
                    if error != nil{
                        print(error!)
                        print("error")
                        return
                    }
                    self.meme_cache_semaphore.signal()
                    self.meme_cache.append(data!)
                    return
                }
                self.meme_cache_semaphore.wait()
                temp = temp + 1
            }
        }
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
