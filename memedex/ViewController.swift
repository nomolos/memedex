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
    
    
    
    @IBOutlet weak var goldensetbutton: UIBarButtonItem!
    let s3bucket = "memedexbucket"
    var keys = [String]()
    var index = 0
    var user:AWSCognitoIdentityUser?
    var userAttributes:[AWSCognitoIdentityProviderAttributeType]?
    var image:UIImage?
    var playerViewController:AVPlayerViewController?
    var user_to_pair_with:String?
    let myGroup = DispatchGroup()
    let mySecondGroup = DispatchGroup()
    let myThirdGroup = DispatchGroup()
    let myFourthGroup = DispatchGroup()
    let myFifthGroup = DispatchGroup()
    let dispatchQueue = DispatchQueue(label: "com.queue.Serial")
    var emitter = CAEmitterLayer()
    
    @IBOutlet weak var meme: UIImageView!
    
    @IBAction func logout(_ sender: Any) {
        print("here23")
        user?.signOut()
        self.fetchUserAttributes()
    
    }
    
    @IBAction func gotogolden(_ sender: Any) {
        print("Going to golden set")
        self.performSegue(withIdentifier: "goldensegue", sender: self)
    }
    
    @objc func sliderValueDidChange(sender:UISlider) {
        if sender.value >= 4.5 {
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
        if(self.keys.count == index+1){
            //vibration indicating failure to go forward
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            return
        }
        //vibration indicating success
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        
        //emitter.emitterShape = kcAEmitt
        // the meme view is hidden because we had a video last time
        // We need to get rid of the AVPlayer used last time
        // Whether or not we initialize another AVPlayer
        if(self.meme.isHidden){
            self.playerViewController?.willMove(toParent: nil)
            self.playerViewController?.view.removeFromSuperview()
            self.playerViewController?.removeFromParent()
        }
        // previous meme being rated
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let meme = Meme()
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
        let transferUtility = AWSS3TransferUtility.default()
        let expression = AWSS3TransferUtilityDownloadExpression()
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
                    return
                }
            })
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.callWhenViewing()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        //self.callWhenViewing()
    }
    
    func callWhenViewing() {
        print("viewDidSomething was called")
        self.navigationItem.rightBarButtonItem?.image = UIImage(named: "goldenset")?.withRenderingMode(.alwaysOriginal)
            slider.isContinuous = false
            slider.minimumValue = 0
            slider.maximumValue = 5
            slider.addTarget(self, action:#selector(sliderValueDidChange(sender:)), for: .allEvents)
            self.fetchUserAttributes()
            let queryExpression = AWSDynamoDBQueryExpression()
            queryExpression.keyConditionExpression = "username = :username"
            queryExpression.expressionAttributeValues = [":username": self.user?.username]
            let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
            let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
            updateMapperConfig.saveBehavior = .updateSkipNullAttributes
            var matches:AWSTask<AWSDynamoDBPaginatedOutput>?
        
            // THIRD QUERY FOR ACTUAL MEMES FROM S3
            // 333333333
            print("333333333")
            self.myFifthGroup.enter()
            self.mySecondGroup.enter()
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
                self.myFifthGroup.leave()
                return nil
            }
        
            // FIRST QUERY FOR PARTNERS TO POTENTIALLY MATCH
            // 11111111
            print("11111111")
            self.myThirdGroup.enter()
            matches = dynamoDBObjectMapper.query(PartnerMatches.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
            if (task.error != nil){
                print("error")
            }
            if (task.result != nil){
                print("here2")
                self.myThirdGroup.leave()
            }
            print("here3")
            return task.result
            }) as! AWSTask<AWSDynamoDBPaginatedOutput>
            
        self.myThirdGroup.notify(queue: .main){
            print("22222222")
            let matches2 = matches?.result?.items
            print(matches2)
            var found_match = false
            if matches2?.count ?? 0 == 1 {
                let user_list = matches2![0] as! PartnerMatches
                let user_list_strings = user_list.getUsers()
                print("printing list of users that we matched with (not necessarily active today)")
                print(user_list_strings)
                for paired_user in user_list_strings{
                    print("We are now looking for the first matched user who was active today")
                    queryExpression.expressionAttributeValues = [":username": paired_user]
                    
                    // SECOND QUERY FOR PARTNER WHO WAS ACTIVE
                    // 222222222
                    self.myFourthGroup.enter()
                    let active_matches = dynamoDBObjectMapper.query(ActiveUser.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
                    if (task.error != nil){
                        print("error")
                    }
                    if (task.result != nil){
                        print("here2")
                        self.myFourthGroup.leave()
                    }
                    print("here3")
                    return task.result
                    }) as! AWSTask<AWSDynamoDBPaginatedOutput>
                    self.myFourthGroup.notify(queue: .main){
                        let returned_matches = active_matches.result?.items
                        if returned_matches?.count ?? 0 == 1 {
                            print("We found a user match who was active today!")
                            print("Their user id is " + paired_user)
                            found_match = true
                            self.user_to_pair_with = paired_user
                        }
                    }
                }
            }
            else {
                let alert = UIAlertController(title: "Fill Out the Golden Set!", message: "Click on the treasure chest icon and rate 13 memes in order to get the most out of our recommendation system :)", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: nil))
                self.present(alert, animated: true)
            }
            

            // THIS GROUP IS DEPENDENT ON QUERY 2
            // THIS GROUP IS DEPENDENT ON QUERY 1
            // 444444444
            self.myFourthGroup.notify(queue: .main){
            print("444444444")
            if found_match{
                queryExpression.keyConditionExpression = "username = :username"
                queryExpression.expressionAttributeValues = [":username": self.user_to_pair_with]
                let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
                let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
                updateMapperConfig.saveBehavior = .updateSkipNullAttributes
                var matches5: AWSTask<AWSDynamoDBPaginatedOutput>?
                self.myGroup.enter()
                self.dispatchQueue.async{
                    print("here1 in dispatch queue sync 1")
                    // FOURTH QUERY FOR MEME NAMES OF RECOMMENDED MEMES
                    matches5 = dynamoDBObjectMapper.query(Meme.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
                    if (task.error != nil){
                        print("error")
                    }
                    if (task.result != nil){
                        print("here2")
                        self.myGroup.leave()
                    }
                    print("here3")
                    return task.result
                    }) as! AWSTask<AWSDynamoDBPaginatedOutput>
                }
                // THIS GROUP IS DEPENDENT ON QUERY FOUR
                // THIS GROUP IS ALSO DEPENDENT ON QUERY 3
                // 555555555
                self.myGroup.notify(queue: self.dispatchQueue){
                    print("555555555")
                    print(self.myGroup)
                    //self.myGroup.enter()
                    print("here4")
                    var all_ratings_of_partner = matches5?.result?.items
                    print("our partner has labeled a total of " + String(all_ratings_of_partner!.count) + " memes")
                    var temp_keys = [String]()
                    print("here5")
                    for meme_rating_pair in all_ratings_of_partner!{
                        var meme_rating_pair2 = meme_rating_pair as! Meme
                        // We want this rating
                        if(self.keys.contains(meme_rating_pair2.meme as! String)){
                            print("Our partners rating below")
                            print(String(Double(meme_rating_pair2.rating!)))
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
                    for keyster in self.keys{
                        temp_keys.append(keyster)
                    }
                    self.keys = temp_keys
                    print("This meme should be at the front " + self.keys[0])
                    self.mySecondGroup.leave()
                    }
            }
            else{
                let alert = UIAlertController(title: "No Matched User", message: "We could not find a user to match you with :( Your ratings will be immensely helpeful in recommending memes to other users today", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: nil))
                self.present(alert, animated: true)
            }
            }
            // THIS GROUP IS DEPENDENT ON QUERY FOUR AND THE BLOCK ABOVE AS WELL
            // 66666666666
            self.myFifthGroup.notify(queue: .main){
            self.mySecondGroup.notify(queue: .main){
                print("66666666")
                print("This meme is at the front " + self.keys[0])
                let transferUtility = AWSS3TransferUtility.default()
                let expression = AWSS3TransferUtilityDownloadExpression()
                
                // FIFTH QUERY TO ACTUALLY DOWNLOAD NEXT IMAGE/VIDEO/GIF FROM S3
                transferUtility.downloadData(fromBucket: self.s3bucket, key: self.keys[self.index], expression: expression) { (task, url, data, error) in
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
                            return
                        }
                    })
                }
            }
            }
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
}

