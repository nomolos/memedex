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
import Amplify
import AWSSNS
import Photos

class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return groups.count
    }
    
    var groups = [String]()
    var groupname:UITextField?
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return groups[row]
    }
    
    func pickerView( _ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.groupname?.text = groups[row]
    }

    let s3bucket = "memedexbucket"
    var keys = [String]()
    var previous_keys = [String]()
    var index = 0
    var downloaded_index = 0
    var index_for_cache = 0
    var user:AWSCognitoIdentityUser?
    @IBOutlet weak var imageView: UIImageView!
    var image:UIImage?
    var playerViewController:AVPlayerViewController?
    var user_to_pair_with:String?
    let waitPartnerMemes = DispatchGroup()
    let waitGroupNames = DispatchGroup()
    let waitGroupNamesFinal = DispatchGroup()
    let waitUserSubsPushNotification = DispatchGroup()
    let waitMemesUpdated = DispatchGroup()
    let waitPotentialPartners = DispatchGroup()
    let waitPotentialActivePartner = DispatchGroup()
    let waitFinalPartner = DispatchGroup()
    let waitMemeNamesS3 = DispatchGroup()
    let waitPotentialActivePartner2 = DispatchGroup()
    let waitURL = DispatchGroup()
    let waitTopSources = DispatchGroup()
    let waitNonFBUser = DispatchGroup()
    let waitCheckMemeNames = DispatchGroup()
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
    var previous_num_memes = -1
    var show_share_popup = 0
    var videoPanGesture:UIPanGestureRecognizer?
    var top_sources = [String]()
    var fromGroups = false
    var sliderSignalSentFromSwipe = false
    static let key_1 = "key_1"
    static let key_2 = "key_2"
    static let key_3 = "key_3"
    
    @IBOutlet weak var back_button: UIButton!
    var meme_link:UIButton?
    var meme_group_add:UIButton?
    
    @IBOutlet weak var shareButton2: UIButton!

    @IBOutlet weak var saveButton: UIButton!
    
    @IBOutlet var meme: ImageZoomView!
    
    @IBAction func logout(_ sender: Any) {
        let alert = UIAlertController(title: "Sign Out", message: "Do you want to sign out?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (action: UIAlertAction!) in
            self.dismiss(animated: true, completion: nil)
            if(AppDelegate.socialLoggedIn!){
                AppDelegate.socialLoggedIn = false
                _ = Amplify.Auth.signOut() { result in
                    switch result {
                    case .success:
                        print("Successfully signed out")
                    case .failure(let error):
                        print("Sign out failed with error \(error)")
                    }
                }
            }
            else {
                // Don't change logged in variable, it'll be modified in LoginViewController
                // AppDelegate.loggedIn = false
                AppDelegate.defaultUserPool().currentUser()?.signOut()
            }
            self.fetchUserAttributes()
            return
        }))
        alert.addAction(UIAlertAction(title: "No", style: .default, handler: { (action: UIAlertAction!) in
            return
        }))
        self.present(alert, animated: true)
    }

    @objc func addMemeToGroup(_ sender:UIButton) {
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
        self.waitGroupNamesFinal.enter()
        self.loadGroupNames()
        self.waitGroupNamesFinal.notify(queue: .main){
            let alert = UIAlertController(title: "Add to Group", message: "Add this meme to a group", preferredStyle: .alert)
            self.groupname = UITextField()
            var caption = UITextField()
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { (action: UIAlertAction!) in
                return
            }))
            alert.addTextField(configurationHandler: {(textfield: UITextField!) in
                textfield.placeholder = "Group name"
                self.groupname = textfield
                let pickerView = UIPickerView(frame:
                    CGRect(x: 0, y: 50, width: 260, height: 162))
                pickerView.dataSource = self
                pickerView.delegate = self
                // comment this line to use white color
                pickerView.backgroundColor = UIColor.white
                textfield.inputView = pickerView
            })
            alert.addTextField(configurationHandler: {(textfield: UITextField!) in
                textfield.placeholder = "Caption"
                caption = textfield
            })
            alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { (action: UIAlertAction!) in
                let key = self.keys[self.index]
                let upload_me = self.meme.imageView.image
                let upload_data : Data = (upload_me?.pngData())!

                let completionHandler = { (task:AWSS3TransferUtilityUploadTask, error:NSError?) -> Void in
                    if(error != nil){
                        print("Failure uploading file")
                        
                    }else{
                        print("Success uploading file")
                    }
                } as? AWSS3TransferUtilityUploadCompletionHandlerBlock
                
                // Upload meme to S3
                let expression  = AWSS3TransferUtilityUploadExpression()
                let transferUtility = AWSS3TransferUtility.default()
                transferUtility.uploadData(upload_data, bucket: self.s3bucket, key: (self.groupname!.text! + "/" + key), contentType: "image/png", expression: expression, completionHandler: completionHandler).continueWith { (task) -> Any? in
                    if let error = task.error {
                        print("Error : \(error.localizedDescription)")
                    }

                    if task.result != nil {
                        print(task.result)
                    }

                    return nil
                }
                // Upload caption to S3
                var caption_to_send = Caption()
                caption_to_send?.caption = caption.text as! NSString
                caption_to_send?.imagepath = (self.groupname!.text! + "/" + self.keys[self.index]) as! NSString
                let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
                let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
                updateMapperConfig.saveBehavior = .updateSkipNullAttributes
                dynamoDBObjectMapper.save(caption_to_send!, configuration: updateMapperConfig).continueWith(block: { (task:AWSTask<AnyObject>!) -> Any? in
                    if let error = task.error as NSError? {
                        print("The request failed. Error: \(error)")
                    } else {
                        print("Caption should have been sent")
                        // Do something with task.result or perform other operations.
                    }
                    return 0
                })
                
                // Send Push Notifications to others in group
                self.waitUserSubsPushNotification.enter()
                let scanExpression = AWSDynamoDBScanExpression()
                updateMapperConfig.saveBehavior = .updateSkipNullAttributes
                let user_subs = dynamoDBObjectMapper.scan(UserSub.self, expression: scanExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
                    if (task.error != nil){
                        print("Error scanning for UserSubs in addMemeToGroup before push notification")
                        print(task.error)
                    }
                    if (task.result != nil){
                        print("Successfully scanned user_subs table, about to send notifications to a subset of them")
                    }
                    self.waitUserSubsPushNotification.leave()
                    return task.result
                }) as! AWSTask<AWSDynamoDBPaginatedOutput>
                
                self.waitUserSubsPushNotification.notify(queue: .main){
                    //print("PRINTING WHAT WE HAVE ADDMEMETOGROUP")
                    DispatchQueue.main.async{
                        let group_name_temp = (self.groupname?.text)!
                        let user_subs_returned = user_subs.result?.items
                        for user1 in user_subs_returned! {
                            let casted = user1 as! UserSub
                            print(casted)
                            if casted.groups != nil && casted.groups.count != 0 && casted.groups.contains((self.groupname?.text) as! NSString){
                                print(group_name_temp)
                                print(casted.sub as! String)
                                print("Should be sending a notification to " + (casted.sub as! String))
                                self.sendSNSPushNotification(group: group_name_temp, receiverSub: (casted.sub as! String))
                            }
                        }
                    }
                }
                print("addToMemeGroup")
            }))
            self.present(alert, animated: true)
        }
    }
    
    func sendSNSPushNotification(group: String, receiverSub: String) {
        print("inside sendSNSPushNotification")
        let queryExpression = AWSDynamoDBQueryExpression()
        queryExpression.keyConditionExpression = "#sub2 = :sub"
        queryExpression.expressionAttributeNames = ["#sub2": "sub"]
        queryExpression.expressionAttributeValues = [":sub": receiverSub]
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
        updateMapperConfig.saveBehavior = .updateSkipNullAttributes
        var somefin = dynamoDBObjectMapper.query(SNSEndpoint.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
        if (task.error != nil){
            print("error in querying for User : " + receiverSub + " in sendSNSPushNotification")
            print(task.error)
        }
        if (task.result != nil){
            print("Successfully queried for User : " + receiverSub + " in sendSNSPushNotification")
            if(task.result?.items.count != 0){
                let castedSNSUser = task.result?.items[0] as! SNSEndpoint
                if(castedSNSUser.endpoint != nil && castedSNSUser.endpoint != ("" as! NSString)){
                    let sns = AWSSNS.default()
                    let request = AWSSNSPublishInput()
                    request?.targetArn = castedSNSUser.endpoint as! String
                    request?.message = "Someone added a meme to your group : " + group
                    sns.publish(request!, completionHandler: ({ (response: AWSSNSPublishResponse?, err: Error?) in
                        if(err != nil){
                            print("Printing error sendSNSPushNotification")
                            print(err)
                        }
                        else{
                            print("Printing response sendSNSPushNotification")
                            print(response)
                        }
                    }))
                }
            }
            else{
                print("We don't have this user's endpoint : " + receiverSub + " either they didn't enable notifications or theres a bug")
            }
        }
        return task.result
        }) as! AWSTask<AWSDynamoDBPaginatedOutput>
    }
    
    
    @objc func goToURL(_ sender:UIButton) {
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
        let alert = UIAlertController(title: "Leaving memedex", message: "Do you want to go to the site where this meme was posted?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { (action: UIAlertAction!) in
            return
        }))
        alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: { (action: UIAlertAction!) in
            let queryExpression = AWSDynamoDBQueryExpression()
            queryExpression.keyConditionExpression = "memename = :memename"
            let spliced = self.keys[self.index].dropFirst(12)
            queryExpression.expressionAttributeValues = [":memename": spliced]
            let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
            let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
            updateMapperConfig.saveBehavior = .updateSkipNullAttributes
            self.waitURL.enter()
            self.activityIndicator.startAnimating()
            var somefin = dynamoDBObjectMapper.query(URL4Meme.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
            if (task.error != nil){
                print("error in querying for URL fuckshitdamn")
            }
            if (task.result != nil){
                print("no error in querying for URL hooray!")
            }
            self.waitURL.leave()
            return task.result
            }) as! AWSTask<AWSDynamoDBPaginatedOutput>
            self.waitURL.notify(queue: .main){
                let urley = somefin.result!.items[0] as! URL4Meme
                var urley_string = String(urley.URL!)
                self.activityIndicator.stopAnimating()
                UIApplication.shared.open(URL(string: urley_string)!)
            }
        }))
        self.present(alert, animated: true)
    }
    

    
    @IBAction func saveImage(_ sender: UIButton) {
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
        let imageExtensions = ["png", "jpg","JPG","PNG", "gif", "ifv"]
        let last3 = self.keys[self.index].suffix(3)
        if imageExtensions.contains(String(last3)){
            if last3.contains("gif") || last3.contains("ifv"){
                print("we have a gif, not saving it")
                guard let saveMe = self.image else {return}
                UIImageWriteToSavedPhotosAlbum(saveMe, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
            }
            else{
                guard let saveMe = self.meme.imageView.image else { return }
                UIImageWriteToSavedPhotosAlbum(saveMe, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
            }
        }
        else{
            print("we have a video")
            let temp0_url = GetAWSObjectURL().getPreSignedURL(S3DownloadKeyName: self.keys[self.index])
            //let temp_url = URL(string: temp0_url)!
            DispatchQueue.global(qos: .background).async {
                if let url = URL(string: temp0_url), let urlData = NSData(contentsOf: url) {
                   let galleryPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0];
                   let filePath="\(galleryPath)/nameX.mp4"
                   DispatchQueue.main.async {
                      urlData.write(toFile: filePath, atomically: true)
                         PHPhotoLibrary.shared().performChanges({
                         PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL:
                         URL(fileURLWithPath: filePath))
                      }) {
                         success, error in
                         if success {
                            DispatchQueue.main.async {
                                let alertController = UIAlertController(title: "Your video was successfully saved", message: nil, preferredStyle: .alert)
                                let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                                alertController.addAction(defaultAction)
                                self.present(alertController, animated: true, completion: nil)
                            }
                            print("Succesfully Saved")
                         } else {
                            print(error?.localizedDescription)
                         }
                      }
                   }
                }
            }
        }
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            // we got back an error!
            let ac = UIAlertController(title: "Save failed for some reason", message: "Please email memedex2020@gmail.com if this happens", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        } else {
            DispatchQueue.main.async {
                let alertController = UIAlertController(title: "Your photo was successfully saved", message: nil, preferredStyle: .alert)
                let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                alertController.addAction(defaultAction)
                self.present(alertController, animated: true, completion: nil)
            }
            print("Save succeeded")
        }
    }
    
    @IBAction func share(_ sender: UIButton) {
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
        let imageExtensions = ["png", "jpg","JPG","PNG", "gif", "ifv"]
        let last3 = self.keys[self.index].suffix(3)
        if imageExtensions.contains(String(last3)){
            //we've got a gif
            if last3.contains("gif") || last3.contains("ifv"){
                var share_me = self.image
                let share_me_container = [share_me] as [Any]
                let activityViewController = UIActivityViewController(activityItems: share_me_container, applicationActivities: nil)
                activityViewController.popoverPresentationController?.sourceView = self.view
                self.present(activityViewController, animated: true, completion: nil)
            }
            else{
                var share_me = self.meme.imageView.image
                let text_to_share = "Download memedex on the App Store: "
                let objectsToShare:URL = URL(string: "https://itunes.apple.com/app/id1513434848")!
                share_me = UIImage(data: share_me!.jpegData(compressionQuality: 0.1)!)!
                let share_me_container = [share_me, text_to_share, objectsToShare] as [Any]
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
    }
    
    
    
    
    
    @IBAction func back(_ sender: Any) {
        self.back_button.isEnabled = false
        if(self.index > 0){
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            self.back_button.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            UIView.animate(withDuration: 2.0,
                                       delay: 0,
                                       usingSpringWithDamping: CGFloat(0.20),
                                       initialSpringVelocity: CGFloat(6.0),
                                       options: UIView.AnimationOptions.allowUserInteraction,
                                       animations: {
                                        self.back_button.transform = CGAffineTransform.identity
                },
                                       completion: { Void in()  }
            )
            self.index = self.index - 2
            // Change something here
            self.index_for_cache = 0
            self.downloaded_index = 0
            self.loadNextMeme(first: false, direction: false)
        }
        else{
            let alert = UIAlertController(title: "Back button", message: "You can't go back since this is the first meme", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: nil))
            self.present(alert, animated: true)
            return
        }
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
        if(self.meme.imageView != nil && !sliderSignalSentFromSwipe){
            self.meme.handlePansFromViewControllerSlider(thumbCenter: self.slider.thumbCenterX)
        }
    }
    
    @IBOutlet weak var slider: CustomSlider!
    
    

    @IBAction func swipeLeft(_ sender: Any) {
        print("inside swipeLeft")
        self.next(self)
    }
    
    
    
    @IBAction func next(_ sender: Any) {
        if(self.meme != nil && self.meme.imageView != nil){
            //self.meme.imageView.center
            self.meme.imageView.transform = CGAffineTransform.identity
            self.meme.ultimate_center_set = false
        }
        self.sliderSignalSentFromSwipe = false
        self.slider.isEnabled = false
        // This user is active
        // Send a notification to Dynamo
        // Adds them to today's Active Users table
        // Want to update this after every 10 labels
        if(self.index == 0 || (self.index % 10 == 0)){
            var active_user = ActiveUser()
            if(AppDelegate.socialLoggedIn!){
                active_user?.username = AppDelegate.social_username as! NSString
            }
            else{
                active_user?.username = AppDelegate.defaultUserPool().currentUser()?.username as! NSString
            }
            active_user?.num_ratings = (self.index + 1) as! NSNumber
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
        if(self.index + 1 == self.last_recommended_index){
            let alert = UIAlertController(title: "End of Recommendations", message: "You looked through all the recommended memes! Now you're surfing the internet :)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self.present(alert, animated: true)
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
        if(slider.value > 4.5){
            self.show_share_popup = self.show_share_popup + 1
        }
        if(self.show_share_popup == 3){
            let alert = UIAlertController(title: "Share this meme?", message: "Sharing memes helps us buy groceries", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Heck No", style: .default, handler: { (action: UIAlertAction!) in
                self.rateCurrentMeme()
                print("about to call loadNextMeme line 558")
                self.loadNextMeme(first: false, direction: true)
            }))
            alert.addAction(UIAlertAction(title: "Heck Yes", style: .default, handler: { (action: UIAlertAction!) in
                self.share(self.shareButton2)
                return
            }))
            self.present(alert, animated: true)
            self.slider.isEnabled = true
            self.show_share_popup = self.show_share_popup + 1
        }
        else{
            self.rateCurrentMeme()
            print("about to call loadNextMeme line 571")
            self.loadNextMeme(first: false, direction: true)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureSlider()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("here inside viewWillDisappear viewcontroller")
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func update_slider() {
        self.slider.value = ImageZoomView.slider_value! - 0.5
        self.sliderSignalSentFromSwipe = true
        self.sliderValueDidChange(sender: self.slider)
    }
    
    @objc func applicationWillEnterForeground(_ notification: NSNotification) {
        //self.volumeSlider.value = AVAudioSession.sharedInstance().outputVolume
        print("here inside applicationWillEnterForeground viewcontroller")
        var temp_keys = [String]()
        //print(self.keys.count)
        //print(self.previous_keys.count)
        self.waitCheckMemeNames.enter()
        let s3 = AWSS3.s3(forKey: "defaultKey")
        let listRequest: AWSS3ListObjectsRequest = AWSS3ListObjectsRequest()
        listRequest.bucket = s3bucket
        listRequest.prefix = "actualmemes/"
        s3.listObjects(listRequest).continueWith { (task) -> AnyObject? in
            let listObjectsOutput = task.result;
            if(task.error != nil || listObjectsOutput == nil || listObjectsOutput?.contents == nil){
                print("PRINTING ERROR LOADING S3 MEMES")
                print(task.error)
                DispatchQueue.main.sync{
                    let alert = UIAlertController(title: "No Memes Right Now", message: "memedex is currently searching the internet for the latest memes. Usually this happens around 12AM Central Time (US) and lasts 20 minutes", preferredStyle: .alert)
                    self.present(alert, animated: true)
                }
                return nil
            }
            for object in (listObjectsOutput?.contents)! {
                //print(object.)
                //print("PRINTING WHEN OBJECT WAS MODIFIED")
                //print(object.lastModified)
                temp_keys.append(String(object.key!))
                //print(String(object.key!))
            }
            self.waitCheckMemeNames.leave()
            return nil
        }
        self.waitCheckMemeNames.notify(queue: .main){
            print("there are this many keys in S3 : " + String(temp_keys.count))
            print("there are this many keys with us now : " + String(self.keys.count))
            if(temp_keys.count != self.keys.count){
                DispatchQueue.main.async{
                    let alert = UIAlertController(title: "New Day Of Memes", message: "There are new memes available", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Go!", style: .default, handler: { (action: UIAlertAction!) in
                        self.keys = [String]()
                        self.index = 0
                        self.downloaded_index = 0
                        self.index_for_cache = 0
                        self.meme_cache = [Data]()
                        self.top_sources = [String]()
                        let nc = NotificationCenter.default
                        nc.removeObserver(self)
                        self.viewWillAppear(true)
                        //self.loadNextMeme(first: true, direction: true)
                        //self.updateUI(direction: true)
                    }))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(
        self,
        selector: #selector(applicationWillEnterForeground(_:)),
        name: UIApplication.willEnterForegroundNotification,
        object: nil)
        print("inside viewWillAppear ViewController")
        if(self.fromGroups){
            let nc = NotificationCenter.default
            nc.addObserver(self, selector: #selector(swipeLeft(_:)), name: NSNotification.Name(rawValue: "next"), object: nil)
            nc.addObserver(self, selector: #selector(back(_:)), name: NSNotification.Name(rawValue: "back"), object: nil)
            nc.addObserver(self, selector: #selector(update_slider), name: NSNotification.Name(rawValue: "update_slider"), object: nil)
            self.fromGroups = false
            return
        }
        super.viewWillAppear(animated)
        self.show_share_popup = 0
        let hacky_scene_access = UIApplication.shared.connectedScenes.first
        let scene_delegate = hacky_scene_access?.delegate as! SceneDelegate
        scene_delegate.viewController = self
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(swipeLeft(_:)), name: NSNotification.Name(rawValue: "next"), object: nil)
        nc.addObserver(self, selector: #selector(back(_:)), name: NSNotification.Name(rawValue: "back"), object: nil)
        nc.addObserver(self, selector: #selector(update_slider), name: NSNotification.Name(rawValue: "update_slider"), object: nil)
        
        if(self.meme_link == nil || self.meme_group_add == nil){
            self.meme_link = UIButton()
            self.meme_group_add = UIButton()
            let temp_image = UIImage(named: "link") as UIImage?
            var temp_image2 = UIImage(named: "addToGroup") as UIImage?
            self.meme_link?.setImage(temp_image, for: .normal)
            self.meme_group_add?.setImage(temp_image2, for: .normal)
            self.meme_group_add?.frame = CGRect(x: 100,y: 100,width: 27,height: 27)
            
            
            self.meme_link?.frame = CGRect(x: 100,y: 100,width: 31,height: 27)
            self.meme_group_add?.isHidden = true
            self.meme_link?.isHidden = true
            self.view.addSubview(self.meme_link!)
            self.view.addSubview(self.meme_group_add!)
        }
        
        self.activityIndicator = UIActivityIndicatorView()
        self.activityIndicator.color = UIColor.white
        self.activityIndicator.style = UIActivityIndicatorView.Style.large
        self.activityIndicator.frame = CGRect(x: self.view.bounds.midX - 50, y: self.view.bounds.midY - 100, width: 100, height: 100)
        self.activityIndicator.hidesWhenStopped = true
        self.activityIndicator.layer.zPosition = 1
        view.addSubview(self.activityIndicator)
        self.activityIndicator.startAnimating()
        AppDelegate.loggedIn = true
        self.waitMemeNamesS3.enter()
        self.waitMemesUpdated.enter()
        self.loadAllS3MemeNames()
        self.waitPotentialPartners.enter()
        self.waitFinalPartner.enter()
        // Just looks for active users, don't need to know our username yet
        self.findPartnerMatchesPart1()
        self.waitPotentialPartners.notify(queue: .main){
            print("done waiting to see if we have some active users today")
            print("done waiting to see if we have a non FB User")
            AppDelegate.waitSocialUser.notify(queue: .main){
                if(!AppDelegate.socialLoggedIn! && AppDelegate.defaultUserPool().currentUser()?.username == nil){
                    print("we don't have a FB User, Apple User, or regular user.. this is a problem. Signing out")
                    self.dismiss(animated: true, completion: nil)
                    AppDelegate.socialLoggedIn = false
                    _ = Amplify.Auth.signOut() { result in
                        switch result {
                        case .success:
                            print("Successfully signed out")
                        case .failure(let error):
                            print("Sign out failed with error \(error)")
                        }
                    }
                    AppDelegate.defaultUserPool().currentUser()?.signOut()
                    self.fetchUserAttributes()
                    return
                }
                print("PRINTING USER IN VIEWCONTROLLER")
                print("PRINTING USER IN VIEWCONTROLLER")
                if(AppDelegate.socialLoggedIn!){
                    print("social logged in")
                    print(AppDelegate.social_username)
                }
                else{
                    print("No social login, printing regular username")
                    print(AppDelegate.defaultUserPool().currentUser()?.username)
                }
                print("PRINTING USER IN VIEWCONTROLLER")
                print("PRINTING USER IN VIEWCONTROLLER")
                self.findPartnerMatchesPart2()
                self.waitTopSources.enter()
                self.loadTopSources()
                self.waitFinalPartner.notify(queue: .main){
                    print("notified about final partner")
                    self.waitMemeNamesS3.notify(queue: .main){
                        self.waitTopSources.notify(queue: .main){
                            print("have our meme names S3")
                            // We have a previous state
                            // We have a previous state
                            if(self.previous_num_memes != -1){
                                print("we have a previous state")
                                // This previous state was from a different day
                                // This previous state was from a different day
                                // shuffle and prioritize top sources
                                // load partners recommended memes afterwards if we have them
                                if(self.previous_num_memes != self.keys.count){
                                    print("This previous state was from a different day")
                                    self.keys.shuffle()
                                    self.waitTopSources.notify(queue: .main){
                                        // only prioritizing very top source for now
                                        //print("printing our top sources in viewdidappear")
                                        //print(self.top_sources[0])
                                        if self.top_sources.count != 0{
                                            print("about to loop through keys and move top sources up")
                                            var current_index = 0
                                            var swap_index = 0
                                            print("OUR TOP SOURCES BELOW")
                                            print(self.top_sources)
                                            for keyster in self.keys{
                                                if keyster.contains(self.top_sources[0]) || keyster.contains(self.top_sources[1]) || keyster.contains(self.top_sources[2]){
                                                    print(keyster + " contains substring " + self.top_sources[0])
                                                    self.keys.swapAt(current_index, swap_index)
                                                    swap_index = swap_index + 1
                                                }
                                                current_index = current_index + 1
                                            }
                                        }
                                        self.index = 0
                                        if self.found_match{
                                            print("we found a match - the user we're matched with is " + self.user_to_pair_with!)
                                            self.loadMemesRecommendedByPartner()
                                        }
                                        else{
                                            let alert = UIAlertController(title: "No A.I.", message: "We could not find memes to recommend to you", preferredStyle: .alert)
                                            alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: nil))
                                            self.present(alert, animated: true)
                                            self.waitMemesUpdated.leave()
                                        }
                                        self.waitMemesUpdated.notify(queue: .main){
                                            print("About to call loadNextMeme line 787")
                                            self.loadNextMeme(first: true, direction: true)
                                        }
                                    }
                                }
                                // This previous state was from a different day END
                                // This previous state was from a different day END
                                
                                // The previous state was from today
                                // The previous state was from today
                                else{
                                    print("This previous state was from today")
                                    self.activityIndicator.stopAnimating()
                                    self.keys = self.previous_keys
                                    print("About to call loadNextMeme line 802")
                                    self.loadNextMeme(first: true, direction: true)
                                }
                            }
                            // We have a previous state END
                            // We have a previous state END
                                    
                            // We don't have a previous state
                            // shuffle and prioritize top sources
                            else{
                                print("we don't have a previous state")
                                self.keys.shuffle()
                                self.waitTopSources.notify(queue: .main){
                                    //print("printing our top sources in viewdidappear")
                                    //print(self.top_sources[0])
                                    if self.top_sources.count != 0{
                                        var current_index = 0
                                        var swap_index = 0
                                        for keyster in self.keys{
                                            // only prioritizing very top source for now
                                            if keyster.contains(self.top_sources[0]) || keyster.contains(self.top_sources[1]) || keyster.contains(self.top_sources[2]){
                                                print(keyster + " contains substring " + self.top_sources[0])
                                                self.keys.swapAt(current_index, swap_index)
                                                swap_index = swap_index + 1
                                            }
                                            current_index = current_index + 1
                                        }
                                    }
                                    self.index = 0
                                    if self.found_match{
                                        self.loadMemesRecommendedByPartner()
                                    }
                                    else{
                                        let alert = UIAlertController(title: "No A.I.", message: "We could not find memes to recommend to you", preferredStyle: .alert)
                                        alert.addAction(UIAlertAction(title: "Continue", style: .default, handler: nil))
                                        self.present(alert, animated: true)
                                        self.activityIndicator.stopAnimating()
                                        self.waitMemesUpdated.leave()
                                    }
                                    self.waitMemesUpdated.notify(queue: .main){
                                        self.activityIndicator.stopAnimating()
                                        self.loadNextMeme(first: true, direction: true)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func rateCurrentMeme() {
        // If they've given
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let meme = Meme()
        if(AppDelegate.socialLoggedIn!){
            meme?.username = AppDelegate.social_username as! NSString
        }
        else{
            meme?.username = AppDelegate.defaultUserPool().currentUser()?.username as! NSString
        }
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
    
    func loadNextMeme(first: Bool, direction: Bool) {
        self.activityIndicator.startAnimating()
        if(!first){
            self.index = self.index + 1
        }
        let transferUtility = AWSS3TransferUtility.default()
        let expression = AWSS3TransferUtilityDownloadExpression()
        // Very first meme of the session
        // OR We haven't downloaded the next meme that we want
        if(self.index >= self.keys.count){
            print("should not be here... probably due to state restoration bug")
            self.index = 0
        }
        if(first || (!(self.downloaded_index > self.index || self.index_for_cache < 0))){
            transferUtility.downloadData(fromBucket: s3bucket, key: self.keys[self.index], expression: expression) { (task, url, data, error) in
                if error != nil{
                    print(error!)
                    print("error")
                    return
                }
                DispatchQueue.main.sync(execute: {
                    let imageExtensions = ["png", "jpg","JPG","PNG", "gif", "ifv"]
                    let last3 = self.keys[self.index].suffix(3)
                    if imageExtensions.contains(String(last3)){
                        //we've got a gif
                        if last3.contains("gif") || last3.contains("ifv"){
                            let gif = UIImage.gifImageWithData(data!)
                            self.image = gif
                        }
                        else{
                            let pic = UIImage(data: data!)
                            //self.image.slideI
                            self.image = pic
                        }
                        if(self.playerViewController != nil){
                            self.playerViewController?.willMove(toParent: nil)
                            self.playerViewController?.view.removeFromSuperview()
                            self.playerViewController?.removeFromParent()
                            self.playerViewController = nil
                            self.player = nil
                        }
                        self.meme.isHidden = false
                        self.imageView.isHidden = false
                        self.updateUI(direction: direction)
                        self.slider.isEnabled = true
                        self.back_button.isEnabled = true
                        self.activityIndicator.stopAnimating()
                        self.background_meme_download()
                        return
                    }
                    else{
                        if(self.playerViewController != nil){
                            self.playerViewController?.willMove(toParent: nil)
                            self.playerViewController?.view.removeFromSuperview()
                            self.playerViewController?.removeFromParent()
                            self.playerViewController = nil
                            self.player = nil
                        }
                        let temp0_url = GetAWSObjectURL().getPreSignedURL(S3DownloadKeyName: self.keys[self.index])
                        let temp_url = URL(string: temp0_url)
                        print("we have a video")
                        if(temp_url == nil){
                            print("this video wasn't loading")
                            self.next(self)
                            return
                        }
                        self.player = AVPlayer(url: temp_url!)
                        print(self.player?.currentItem?.duration)
                        // This video isn't loading properly
                        if(self.player?.currentItem?.duration == CMTime(seconds: 0, preferredTimescale: CMTimeScale())){
                            print("this video wasn't loading")
                            self.next(self)
                            return
                        }
                        self.player?.isMuted = true
                        self.playerViewController = AVPlayerViewController()
                        self.playerViewController?.disableGestureRecognition()
                        self.videoPanGesture = UIPanGestureRecognizer(target: self, action: #selector(self.handleVideoSwipe))
                        self.playerViewController?.view.addGestureRecognizer(self.videoPanGesture!)
                        self.playerViewController!.player = self.player
                        self.playerViewController!.view.frame = self.meme.frame
                        self.addChild(self.playerViewController!)
                        self.view.addSubview(self.playerViewController!.view)
                        self.playerViewController!.didMove(toParent: self)
                        self.player?.play()
                        self.meme.isHidden = true
                        self.imageView.isHidden = true
                        self.updateUI(direction: direction)
                        self.slider.isEnabled = true
                        self.back_button.isEnabled = true
                        self.activityIndicator.stopAnimating()
                        self.background_meme_download()
                        return
                    }
                })
            }
        }
        // We already have the meme we want in a cache
        else{
            self.index_for_cache = self.index_for_cache + 1
            let imageExtensions = ["png", "jpg","JPG","PNG", "gif", "ifv"]
            let last3 = self.keys[self.index].suffix(3)
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
                if(self.playerViewController != nil){
                    self.playerViewController?.willMove(toParent: nil)
                    self.playerViewController?.view.removeFromSuperview()
                    self.playerViewController?.removeFromParent()
                    self.playerViewController = nil
                    self.player = nil
                }
                self.meme.isHidden = false
                self.imageView.isHidden = false
                self.updateUI(direction: direction)
                self.slider.isEnabled = true
                self.back_button.isEnabled = true
                self.activityIndicator.stopAnimating()
                return
            }
            else{
                if(self.playerViewController != nil){
                    self.playerViewController?.willMove(toParent: nil)
                    self.playerViewController?.view.removeFromSuperview()
                    self.playerViewController?.removeFromParent()
                    self.playerViewController = nil
                    self.player = nil
                }
                let temp0_url = GetAWSObjectURL().getPreSignedURL(S3DownloadKeyName: self.keys[self.index])
                let temp_url = URL(string: temp0_url)
                print("we have a video")
                if(temp_url == nil){
                    print("this video wasn't loading")
                    self.next(self)
                    return
                }
                self.player = AVPlayer(url: temp_url!)
                print(self.player?.currentItem?.duration)
                if(self.player?.currentItem?.duration == CMTime(seconds: 0, preferredTimescale: CMTimeScale())){
                    print("this video wasn't loading")
                    self.next(self)
                    return
                }
                self.player?.isMuted = true
                self.playerViewController = AVPlayerViewController()
                self.playerViewController?.disableGestureRecognition()
                self.videoPanGesture = UIPanGestureRecognizer(target: self, action: #selector(self.handleVideoSwipe))
                self.playerViewController?.view.addGestureRecognizer(self.videoPanGesture!)
                self.playerViewController!.player = self.player
                self.playerViewController!.view.frame = self.meme.frame
                self.addChild(self.playerViewController!)
                self.view.addSubview(self.playerViewController!.view)
                self.playerViewController!.didMove(toParent: self)
                self.player?.play()
                self.meme.isHidden = true
                self.imageView.isHidden = true
                self.updateUI(direction: direction)
                self.slider.isEnabled = true
                self.back_button.isEnabled = true
                self.activityIndicator.stopAnimating()
                return
            }
        }
    }
    
    @objc func handleVideoSwipe() {
        self.slider.value = Float((self.videoPanGesture?.location(in: self.view).x)!)/60
        self.sliderValueDidChange(sender: self.slider)
        if self.videoPanGesture!.state == UIGestureRecognizer.State.ended{
            self.next(self)
        }
        // 0 to 330 (call it 300 for max)
        // x / 60
    }
    
    func background_meme_download() {
        self.downloaded_index = index
        self.index_for_cache = 0
        self.meme_cache.removeAll()
        self.dispatchQueue.async{
            let max_10 = self.downloaded_index + 10
            while (self.downloaded_index < self.keys.count && self.downloaded_index <= max_10){
                let transferUtility = AWSS3TransferUtility.default()
                let expression = AWSS3TransferUtilityDownloadExpression()
                transferUtility.downloadData(fromBucket: self.s3bucket, key: self.keys[self.downloaded_index], expression: expression) { (task, url, data, error) in
                    if error != nil{
                        print("error in background meme download")
                        return
                    }
                    self.meme_cache_semaphore.signal()
                    self.meme_cache.append(data!)
                    return
                }
                self.meme_cache_semaphore.wait()
                self.downloaded_index = self.downloaded_index + 1
            }
        }
    }
    
    func loadAllS3MemeNames(){
        let s3 = AWSS3.s3(forKey: "defaultKey")
        let listRequest: AWSS3ListObjectsRequest = AWSS3ListObjectsRequest()
        listRequest.bucket = s3bucket
        listRequest.prefix = "actualmemes/"
        s3.listObjects(listRequest).continueWith { (task) -> AnyObject? in
            let listObjectsOutput = task.result;
            if(task.error != nil || listObjectsOutput == nil || listObjectsOutput?.contents == nil){
                DispatchQueue.main.sync{
                    let alert = UIAlertController(title: "No Memes Right Now", message: "memedex is currently searching the internet for the latest memes. Usually this happens around 12AM Central Time (US) and lasts 20 minutes", preferredStyle: .alert)
                    self.present(alert, animated: true)
                }
                return nil
            }
            for object in (listObjectsOutput?.contents)! {
                self.keys.append(String(object.key!))
            }
            self.waitMemeNamesS3.leave()
            return nil
        }
    }
    
    func loadGroupNames(){
        self.waitGroupNames.enter()
        let queryExpression = AWSDynamoDBQueryExpression()
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
        updateMapperConfig.saveBehavior = .updateSkipNullAttributes
        queryExpression.keyConditionExpression = "#sub2 = :sub"
        queryExpression.expressionAttributeNames = ["#sub2": "sub"]
        if(AppDelegate.socialLoggedIn!){
            queryExpression.expressionAttributeValues = [":sub": AppDelegate.social_username]
        }
        else{
            queryExpression.expressionAttributeValues = [":sub": AppDelegate.defaultUserPool().currentUser()?.username]
        }
        var user_sub_response = dynamoDBObjectMapper.query(UserSub.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
            if (task.error != nil){
                print("error in loadGroupNames")
                print(task.error)
            }
            else if (task.result != nil){
                print("printing result in loadGroupNames")
                print(task.result?.items)
                if(task.result?.items.count == 0){
                    print("We have no items in loadGroupNames, there was no element at this user's sub")
                    return task.result
                }
            }
            self.waitGroupNames.leave()
            return task.result
        }) as! AWSTask<AWSDynamoDBPaginatedOutput>
    
        self.waitGroupNames.notify(queue: .main){
            if (user_sub_response.result?.items.count == 0){
                print("Error in waitGroupNames. There was no user with this sub")
                return
            }
            let casted = user_sub_response.result?.items[0] as! UserSub
            if(casted.groups == nil || casted.groups.count == 0){
                print("No groups for this user in waitGroupNames")
                return
            }
            print("printing group names")
            for group in casted.groups{
                print(group)
                if(!self.groups.contains(group as! String)){
                    self.groups.append(group as! String)
                }
            }
            self.waitGroupNamesFinal.leave()
        }
    }
    
    // EDIT
    func loadTopSources(){
        let queryExpression = AWSDynamoDBQueryExpression()
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
        updateMapperConfig.saveBehavior = .updateSkipNullAttributes
        queryExpression.keyConditionExpression = "username = :username"
        if(AppDelegate.socialLoggedIn!){
            queryExpression.expressionAttributeValues = [":username": AppDelegate.social_username]
        }
        else{
            queryExpression.expressionAttributeValues = [":username": AppDelegate.defaultUserPool().currentUser()?.username]
        }
        var response = dynamoDBObjectMapper.query(TopSources.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
            if (task.error != nil){
                print("error in loadTopSources")
                print(task.error)
                self.waitTopSources.leave()
            }
            if (task.result != nil){
                print("printing result in loadTopSources")
                print(task.result?.items)
                if(task.result?.items.count == 0){
                    print("We have no top sources, likely a new sign up")
                    self.waitTopSources.leave()
                    return task.result
                }
                let temp = task.result?.items[0] as! TopSources
                let first_string = temp.first as! String
                let second_string = temp.second as! String
                let third_string = temp.third as! String
                if(first_string != "nil"){
                    self.top_sources.append(first_string)
                }
                if(second_string != "nil"){
                    self.top_sources.append(second_string)
                }
                if(third_string != "nil"){
                    self.top_sources.append(third_string)
                }
                self.waitTopSources.leave()
            }
        return task.result
        }) as! AWSTask<AWSDynamoDBPaginatedOutput>
        //print("printing response")
        //print(response)
    }
    
    
    // Grab all active uesrs today
    // These are in the users_active_today DynamoDB table
    func findPartnerMatchesPart1() {
        let queryExpression = AWSDynamoDBScanExpression()
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
        updateMapperConfig.saveBehavior = .updateSkipNullAttributes
        self.matches = dynamoDBObjectMapper.scan(ActiveUser.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
        if (task.error != nil){
            print("error in findPartnerMAtches")
            print(task.error)
        }
        if (task.result != nil){
            self.waitPotentialPartners.leave()
        }
        return task.result
        }) as! AWSTask<AWSDynamoDBPaginatedOutput>
    }
    
    // Find the final partner
    // Search through users_active_today
    // Find the person who has labeled the most memes
    // Up until max of 80 [threshold can be changed later]
    func findPartnerMatchesPart2() {
        let matches2 = self.matches?.result?.items
        if matches2?.count ?? 0 >= 1 {
            print("we have a user match")
            var ten_or_more = [String]()
            var twenty_or_more = [String]()
            var thirty_or_more = [String]()
            var forty_or_more = [String]()
            var fifty_or_more = [String]()
            var sixty_or_more = [String]()
            var seventy_or_more = [String]()
            var eighty_or_more = [String]()
            
            for user in matches2!{
                print(user)
                let casted_user = user as! ActiveUser
                if(casted_user.num_ratings == nil){
                    ten_or_more.append(String(casted_user.username!))
                    continue
                }
                if(Int(casted_user.num_ratings!) > 10){
                    ten_or_more.append(String(casted_user.username!))
                }
                if(Int(casted_user.num_ratings!) > 20){
                    twenty_or_more.append(String(casted_user.username!))
                }
                if(Int(casted_user.num_ratings!) > 30){
                    thirty_or_more.append(String(casted_user.username!))
                }
                if(Int(casted_user.num_ratings!) > 40){
                    forty_or_more.append(String(casted_user.username!))
                }
                if(Int(casted_user.num_ratings!) > 50){
                    fifty_or_more.append(String(casted_user.username!))
                }
                if(Int(casted_user.num_ratings!) > 60){
                    sixty_or_more.append(String(casted_user.username!))
                }
                if(Int(casted_user.num_ratings!) > 70){
                    seventy_or_more.append(String(casted_user.username!))
                }
                if(Int(casted_user.num_ratings!) > 80){
                    eighty_or_more.append(String(casted_user.username!))
                }
            }
            // Make partner the person who labeled the most memes today
            // If there are ties, we are just picking the first person who labeled the most memes
            // Eventually we should add more intelligence here
            if(ten_or_more.count > 0){
                self.found_match = true
                if(eighty_or_more.count > 0){
                    self.user_to_pair_with = eighty_or_more[0]
                }
                else if(seventy_or_more.count > 0){
                    self.user_to_pair_with = seventy_or_more[0]
                }
                else if(sixty_or_more.count > 0){
                    self.user_to_pair_with = sixty_or_more[0]
                }
                else if(fifty_or_more.count > 0){
                    self.user_to_pair_with = fifty_or_more[0]
                }
                else if(forty_or_more.count > 0){
                    self.user_to_pair_with = forty_or_more[0]
                }
                else if(thirty_or_more.count > 0){
                    self.user_to_pair_with = thirty_or_more[0]
                }
                else if(twenty_or_more.count > 0){
                    self.user_to_pair_with = twenty_or_more[0]
                }
                else if(ten_or_more.count > 0){
                    self.user_to_pair_with = ten_or_more[0]
                }
                self.waitFinalPartner.leave()
                return
            }
            // Nobody with sufficient labels to build out
            // recommendation
            else{
                print("We don't have a partner")
                self.waitFinalPartner.leave()
            }
        }
        // Nobody with sufficient labels to build out
        // recommendation
        else{
            print("We don't have a partner")
            self.waitFinalPartner.leave()
        }
    }
    
    func loadMemesRecommendedByPartner() {
        let queryExpression = AWSDynamoDBQueryExpression()
        queryExpression.keyConditionExpression = "username = :username"
        queryExpression.expressionAttributeValues = [":username": self.user_to_pair_with!]
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
        updateMapperConfig.saveBehavior = .updateSkipNullAttributes
        var matches5: AWSTask<AWSDynamoDBPaginatedOutput>?
        self.waitPartnerMemes.enter()
        self.dispatchQueue.async{
            // FOURTH QUERY FOR MEME NAMES OF RECOMMENDED MEMES
            matches5 = (dynamoDBObjectMapper.query(Meme.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
                if (task.error != nil){
                    print("error in loadMemesRecommendedByPartner")
                }
                if (task.result != nil){
                    self.waitPartnerMemes.leave()
                }
                return task.result
            }) as! AWSTask<AWSDynamoDBPaginatedOutput>)
        }
        
        // THIS GROUP IS DEPENDENT ON QUERY FOUR
        // THIS GROUP IS ALSO DEPENDENT ON QUERY 3
        // 555555555
        // Needs to have the S3 meme names before
        // we alter the ordering
        self.waitMemeNamesS3.notify(queue: .main){
            self.waitPartnerMemes.notify(queue: self.dispatchQueue){
                let all_ratings_of_partner = matches5?.result?.items
                var temp_keys = [String]()
                for meme_rating_pair in all_ratings_of_partner!{
                    let meme_rating_pair2 = meme_rating_pair as! Meme
                    // We want this rating
                    if(self.keys.contains(meme_rating_pair2.meme! as String)){
                        if(Double(meme_rating_pair2.rating ?? 3) > 3.5){
                            temp_keys.append(meme_rating_pair2.meme as! String)
                            let index_of_boi = self.keys.firstIndex(of: meme_rating_pair2.meme as! String)
                            self.keys.remove(at: index_of_boi!)
                        }
                        /*
                        Currently not down-ranking memes based on partner labels
                        Might want to do this eventually
                         else if(Double(meme_rating_pair2.rating ?? 3) == 0){
                            let index_of_boi = self.keys.firstIndex(of: meme_rating_pair2.meme as! String)!
                            self.keys.remove(at: index_of_boi)
                        }
                        */
                    }
                }
                self.last_recommended_index = temp_keys.count
                for keyster in self.keys{
                    temp_keys.append(keyster)
                }
                self.keys = temp_keys
                self.waitMemesUpdated.leave()
            }
        }
    }
    
    func fetchUserAttributes() {
        AppDelegate.defaultUserPool().currentUser()?.getDetails().continueOnSuccessWith(block: { (task) -> Any? in
            guard task.result != nil else {
                return nil
            }
            return nil
        })
    }
    
    func configureSlider() {
        self.slider.isContinuous = false
        self.slider.minimumValue = 0
        self.slider.maximumValue = 5
        // The end of the drag is sent directly to next. Otherwise it messes with the animations
        self.slider.addTarget(self, action:#selector(sliderValueDidChange(sender:)), for: .touchDragInside)
    }
    
    func updateUI(direction: Bool) {
        if(!self.meme.isHidden){
            self.imageView?.image = self.image
            self.meme = ImageZoomView(frame: self.meme.frame, something: true)
            self.view.addSubview(self.meme)
            if(self.imageView.image != nil){
                self.meme.updateImage(imageView: self.imageView!)
            }
            else{
                self.next(self)
            }
        }
        if((self.image) != nil){
            let real_image_rect = AVMakeRect(aspectRatio: self.meme.getImage().size, insideRect: self.meme.bounds)
            self.meme_link?.frame.origin.x = self.view.frame.width - 47
            self.meme_group_add?.frame.origin.x = 16
            // An image/gif
            if(!self.meme.isHidden){
                self.meme_link?.frame.origin.y = real_image_rect.origin.y + 110
                self.meme_group_add?.frame.origin.y = real_image_rect.origin.y + 110
            }
            // a video
            else{
                self.meme_link?.frame.origin.y = self.meme.frame.origin.y - 32
                self.meme_group_add?.frame.origin.y = self.meme.frame.origin.y - 32
            }
            self.meme_link?.isHidden = false
            self.meme_group_add?.isHidden = false
            self.meme_link?.addTarget(self, action: #selector(goToURL(_:)), for: .touchUpInside)
            self.meme_group_add?.addTarget(self, action: #selector(addMemeToGroup(_:)), for: .touchUpInside)
            self.view.bringSubviewToFront(meme_link!)
            self.view.bringSubviewToFront(meme_group_add!)
        }
    }
    
    // For animation of bubbles off of slider
    func startSpewing(color: Bool) {
        let trackRect =  self.slider.trackRect(forBounds: self.slider.bounds)
        let thumbRect = self.slider.thumbRect(forBounds: self.slider.bounds, trackRect: trackRect, value: self.slider.value)
        self.emitter.emitterPosition = CGPoint(x: thumbRect.origin.x + self.slider.frame.origin.x - 80, y: self.slider.frame.origin.y + 20)
        self.emitter.emitterShape = CAEmitterLayerEmitterShape.line
        self.emitter.emitterSize = CGSize(width: 70.0, height: 2.0)
        self.emitter.emitterCells = generateEmitterCells(color: color)
        self.view.layer.addSublayer(emitter)
    }
    
    // For animation of bubbles off of slider
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
    
    // STATE RESTORATION SO WE RETURN TO THE PROPER SPOT IN THE MEME QUEUE
    func restoreItemInterface(_ activityUserInfo: [AnyHashable: Any]) {
        self.show_share_popup = 0
        if(activityUserInfo[ViewController.key_2] != nil){
            let num_memes = (activityUserInfo[ViewController.key_2] as? Int)
            self.previous_num_memes = num_memes!
        }
        if(activityUserInfo[ViewController.key_1] != nil){
            self.index = (activityUserInfo[ViewController.key_1] as? Int)!
        }
        if(activityUserInfo[ViewController.key_3] != nil){
            self.previous_keys = activityUserInfo[ViewController.key_3] as! [String]
        }
    }

    // STATE RESTORATION SO WE RETURN TO THE PROPER SPOT IN THE MEME QUEUE
    class var activityType: String {
        let activityType = ""
        // Load our activity type from our Info.plist.
        if let activityTypes = Bundle.main.infoDictionary?["NSUserActivityTypes"] {
            if let activityArray = activityTypes as? [String] {
                return activityArray[0]
            }
        }
        return activityType
    }
    
    // STATE RESTORATION SO WE RETURN TO THE PROPER SPOT IN THE MEME QUEUE
    // Used by our scene delegate to return an instance of this class from our storyboard.
    static func loadFromStoryboard() -> ViewController? {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        return storyboard.instantiateViewController(withIdentifier: "ViewController") as? ViewController
    }
    
    // STATE RESTORATION SO WE RETURN TO THE PROPER SPOT IN THE MEME QUEUE
    // Used to construct an NSUserActivity instance for state restoration.
    var detailUserActivity: NSUserActivity {
        self.show_share_popup = 0
        let userActivity = NSUserActivity(activityType: ViewController.activityType)
        userActivity.title = "Restore Item"
        let index_temp : [String:Int] = [ViewController.key_1: self.index]
        let total_memes_temp : [String:Int] = [ViewController.key_2: self.keys.count]
        let previous_memes : [String:[String]] = [ViewController.key_3: self.keys]
        userActivity.addUserInfoEntries(from: index_temp)
        userActivity.addUserInfoEntries(from: total_memes_temp)
        userActivity.addUserInfoEntries(from: previous_memes)
        return userActivity
    }
}
 
 extension ViewController {
    
    // STATE RESTORATION SO WE RETURN TO THE PROPER SPOT IN THE MEME QUEUE
    override func updateUserActivityState(_ activity: NSUserActivity) {
        let userActivity = NSUserActivity(activityType: ViewController.activityType)
        userActivity.title = "Restore Item"
        let index_temp : [String:Int] = [ViewController.key_1: self.index]
        let total_memes_temp : [String:Int] = [ViewController.key_2: self.keys.count]
        let previous_memes : [String:[String]] = [ViewController.key_3: self.keys]
        userActivity.addUserInfoEntries(from: index_temp)
        userActivity.addUserInfoEntries(from: total_memes_temp)
        userActivity.addUserInfoEntries(from: previous_memes)
        super.updateUserActivityState(activity)
    }

    // STATE RESTORATION SO WE RETURN TO THE PROPER SPOT IN THE MEME QUEUE
    override func restoreUserActivityState(_ activity: NSUserActivity) {
        self.show_share_popup = 0
        super.restoreUserActivityState(activity)
        // Check if the activity is of our type.
        if activity.activityType == ViewController.activityType {
            // Get the user activity data.
            //print("activity type does equal our type")
            if let activityUserInfo = activity.userInfo {
                restoreItemInterface(activityUserInfo)
            }
        }
    }
}

// Reset gestures whenever a video is playing (Can't swipe it)
extension AVPlayerViewController {
    func disableGestureRecognition() {
        let contentView = view.value(forKey: "contentView") as? UIView
        contentView?.gestureRecognizers = contentView?.gestureRecognizers?.filter { $0 is UITapGestureRecognizer }
    }
}

// So that button boxes are larger than the icons themselves
// Makes it easier to click them
extension UIButton {
    open override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let newArea = CGRect(
            x: self.bounds.origin.x - 20.0,
            y: self.bounds.origin.y - 20.0,
            width: self.bounds.size.width + 40.0,
            height: self.bounds.size.height + 40.0
        )
        return newArea.contains(point)
    }
}

extension UISlider {
    // returns the x coordinate of the thumb in relation to the UISlider's containing view
    // Used for determine x position when sliding left to right
    // This x position is passed to ImageZoomView for the swipe animation
    var thumbCenterX: CGFloat {
        return thumbRect(forBounds: frame, trackRect: trackRect(forBounds: frame), value: value).midX
    }
}
