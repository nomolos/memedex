//
//  CollectionViewController.swift
//  memedex
//
//  Created by meagh054 on 7/20/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import AWSS3
import AWSCognito
import AWSCognitoIdentityProvider
import AWSCore
import AWSDynamoDB
import AWSSNS
import AVFoundation
import AVKit

private let reuseIdentifier = "Cell"

class CollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, UITextFieldDelegate {

    var meme_container = [Data]()
    var keys = [String]()
    var captions = [String]()
    // only has portion before @
    var sender_emails = [String]()
    let s3bucket = "memedexbucket"
    let meme_collection_semaphore = DispatchSemaphore(value: 0)
    let meme_caption_semaphore = DispatchSemaphore(value: 0)
    let dispatchQueue = DispatchQueue(label: "com.queue.Serial")
    let waitMemeNamesS3 = DispatchGroup()
    var group:String?
    var activityIndicator = UIActivityIndicatorView()
    var modification_times = [Date]()
    var date_to_key = [Date:String]()
    var new_members_textfield = UITextField()
    let adding_user_semaphore = DispatchSemaphore(value: 0)
    let waitUserSub = DispatchGroup()
    var casted_user_sub_item:UserSub?
    var user_emails=[String]()
    let test_textfield = UITextField()
    let waitUserSubsPushNotification = DispatchGroup()
    var waitUserEmails1 = DispatchGroup()
    var waitUserEmails2 = DispatchGroup()
    var user_email:String?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.layer.backgroundColor = UIColor.white.cgColor
        self.navigationController?.navigationBar.layer.opacity = 1.0
        self.navigationController?.navigationBar.layer.shadowColor = UIColor.black.cgColor
        self.navigationController?.navigationBar.layer.shadowOpacity = 0.2
        self.navigationController?.navigationBar.layer.shadowOffset = .zero
        self.navigationController?.navigationBar.layer.shadowRadius = 5
        self.collectionView.backgroundColor = UIColor(red: 0.73, green: 0.49, blue: 0.97, alpha: 1.00)
        self.activityIndicator = UIActivityIndicatorView()
        self.activityIndicator.color = UIColor.white
        self.activityIndicator.style = UIActivityIndicatorView.Style.large
        self.activityIndicator.frame = CGRect(x: self.view.bounds.midX - 50, y: self.view.bounds.midY - 100, width: 100, height: 100)
        self.activityIndicator.hidesWhenStopped = true
        self.activityIndicator.layer.zPosition = 1
        self.collectionView.addSubview(self.activityIndicator)
        self.activityIndicator.startAnimating()
        self.dispatchQueue.async{
            var x = 0
            self.waitMemeNamesS3.enter()
            self.loadAllS3MemeNames()
            self.waitMemeNamesS3.notify(queue: .main){
                while (x < 100 && x < self.keys.count){
                    let transferUtility = AWSS3TransferUtility.default()
                    let expression = AWSS3TransferUtilityDownloadExpression()
                    transferUtility.downloadData(fromBucket: self.s3bucket, key: (self.keys[x] as! String), expression: expression) { (task, url, data, error) in
                        if error != nil{
                            print("error in collection view download")
                            print(error)
                            return
                        }
                        self.meme_collection_semaphore.signal()
                        self.meme_container.append(data!)
                        return
                    }
                    self.meme_collection_semaphore.wait()
                    x = x + 1
                }
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                    self.activityIndicator.stopAnimating()
                }
            }
        }
        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.isHidden = false
        self.collectionView.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor).isActive = true
        self.collectionView!.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        self.collectionView.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, constant: 70).isActive = true
        self.collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -70).isActive = true
        var textfield_container = UIView()
        textfield_container.layer.backgroundColor = UIColor.white.cgColor
        textfield_container.layer.shadowColor = UIColor.black.cgColor
        textfield_container.layer.shadowOpacity = 0.2
        textfield_container.layer.shadowOffset = .zero
        textfield_container.layer.opacity = 1.0
        self.view.addSubview(textfield_container)
        textfield_container.widthAnchor.constraint(equalTo: self.view.widthAnchor).isActive = true
        textfield_container.heightAnchor.constraint(equalToConstant: 150).isActive = true
        textfield_container.topAnchor.constraint(equalTo: self.collectionView.bottomAnchor, constant: -70).isActive = true
        textfield_container.backgroundColor = UIColor.white
        textfield_container.addSubview(test_textfield)
        
        
        let subviewForBugBottomOfScreen = UIView()
        textfield_container.addSubview(subviewForBugBottomOfScreen)
        
        test_textfield.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        test_textfield.widthAnchor.constraint(equalTo: self.view.widthAnchor, constant: -40).isActive = true
        test_textfield.topAnchor.constraint(equalTo: self.collectionView.bottomAnchor, constant: -60).isActive = true
        test_textfield.heightAnchor.constraint(equalToConstant: 40).isActive = true
        test_textfield.borderStyle = UITextField.BorderStyle.roundedRect
        test_textfield.translatesAutoresizingMaskIntoConstraints = false
        textfield_container.translatesAutoresizingMaskIntoConstraints = false
        test_textfield.placeholder = "Start Typing"
        let send_button = UIButton(type: .custom)
        send_button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -16, bottom: 0, right: 0)
        send_button.frame = CGRect(x: CGFloat(test_textfield.frame.size.width - 25), y: CGFloat(5), width: CGFloat(25), height: CGFloat(25))
        send_button.setImage(UIImage(named: "send1.png"), for: .normal)
        send_button.addTarget(self, action: #selector(self.sendMessage), for: .touchUpInside)
        test_textfield.rightView = send_button
        test_textfield.rightViewMode = .whileEditing
        test_textfield.isHidden = false
        test_textfield.layoutIfNeeded()
        textfield_container.layoutIfNeeded()
        self.view.bringSubviewToFront(textfield_container)
        self.view.bringSubviewToFront(test_textfield)
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        subviewForBugBottomOfScreen.frame = CGRect(x: 0.0, y: textfield_container.bounds.height/2 - 10, width: textfield_container.bounds.width, height: textfield_container.bounds.height/2)
        subviewForBugBottomOfScreen.backgroundColor = UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.00)
        subviewForBugBottomOfScreen.layer.opacity = 0.0
        textfield_container.bringSubviewToFront(subviewForBugBottomOfScreen)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if self.view.frame.origin.y == 0 {
                self.view.frame.origin.y -= keyboardSize.height
            }
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        if self.view.frame.origin.y != 0 {
            self.view.frame.origin.y = 0
        }
    }
    
    @IBAction func sendMessage(_ sender: UIButton) {
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
        self.activityIndicator.startAnimating()
        let user_email_plus_message = self.user_email! + "###" + (self.test_textfield.text)!
        let message = user_email_plus_message.data(using: .utf8)
        let randy = self.randomString(length: 20)
        let completionHandler = { (task:AWSS3TransferUtilityUploadTask, error:NSError?) -> Void in
            if(error != nil){
                print("Failure uploading file")
                
            }else{
                print("Success uploading file")
            }
        } as? AWSS3TransferUtilityUploadCompletionHandlerBlock
        let expression  = AWSS3TransferUtilityUploadExpression()
        let transferUtility = AWSS3TransferUtility.default()
        transferUtility.uploadData(message!, bucket: self.s3bucket, key: (self.group! + "/actualmemes/notameme/" + randy), contentType: "text/plain;charset=utf-8", expression: expression, completionHandler: completionHandler).continueWith { (task) -> Any? in
            if let error = task.error {
                print("Error : \(error.localizedDescription)")
            }
            if task.result != nil {
                print(task.result)
            }
            return nil
        }
        self.test_textfield.text = ""
        dismissKeyboard()
        self.view.frame.origin.y = 0
        self.keys.insert((self.group! + "/actualmemes/notameme/" + randy), at: 0)
        self.meme_container.insert(message!, at: 0)
        // Prevents captions from crashing due to
        // indicies not lining up with meme_container and keys
        // Otherwise our # of captions does not equal our # of memes
        self.captions.insert("", at:0)
        DispatchQueue.main.async{
            self.collectionView.reloadData()
            self.collectionView.layoutIfNeeded()
            self.view.layoutIfNeeded()
            self.activityIndicator.stopAnimating()
        }
        // Send Push Notifications to others in group
        self.waitUserSubsPushNotification.enter()
        let scanExpression = AWSDynamoDBScanExpression()
        let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
        updateMapperConfig.saveBehavior = .updateSkipNullAttributes
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
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
            DispatchQueue.main.async{
                let group_name_temp = self.group
                let user_subs_returned = user_subs.result?.items
                var usersub:String?
                if(AppDelegate.socialLoggedIn!){
                    usersub = AppDelegate.social_username
                }
                else if(AppDelegate.loggedIn!){
                    usersub = AppDelegate.defaultUserPool().currentUser()?.username
                }
                else{
                    print("Issue with finding username before sendSNSPushNotification")
                }
                for user1 in user_subs_returned! {
                    let casted = user1 as! UserSub
                    if casted.groups != nil && casted.groups.count != 0 && casted.groups.contains((self.group) as! NSString){
                        if((casted.sub! as String) != usersub){
                            self.sendSNSPushNotification(group: group_name_temp!, receiverSub: (casted.sub as! String))
                        }
                        //self.sendSNSPushNotification(group: group_name_temp!, receiverSub: (casted.sub as! String))
                    }
                }
            }
        }
        
        
        
    }
    
    // Used to generate unique ID for message
    func randomString(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    // Called when sending a message
    func sendSNSPushNotification(group: String, receiverSub: String) {
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
                    request?.message = "Someone sent a message to your group : " + group
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
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
        return self.keys.count
    }

    // Formatting for cells
    // Depends on whether it is a meme w/caption or a message
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
        if(indexPath.row < self.meme_container.count){
            for subview in cell.contentView.subviews{
                subview.removeFromSuperview()
            }
            // Just a message, not a caption
            if(self.keys[indexPath.row].contains("notameme")){
                var message_to_render = String(decoding: self.meme_container[indexPath.row], as: UTF8.self)
                print(message_to_render)
                let parts = message_to_render.components(separatedBy: "###")
                var sender_email = String(parts[0].prefix(8))
                // Since these emails are stored in the message itself
                // We have to append them to their proper place in 'sender_emails'
                if(parts.count > 1){
                    message_to_render = parts[1]
                    self.sender_emails.insert(sender_email, at: indexPath.row)
                }
                else{
                    message_to_render = parts[0]
                    sender_email = "unknown"
                    self.sender_emails.insert(sender_email, at: indexPath.row)
                }

                let label_superview_for_padding = UIView(frame: CGRect(x: 20, y: cell.contentView.frame.minY + 20, width: self.view.frame.width - 40, height: (100)))
                let label_for_cell = UILabel(frame: CGRect(x: 10, y: cell.contentView.frame.minY, width: self.view.frame.width - 60, height: (100)))
                
                label_superview_for_padding.layer.backgroundColor = UIColor.white.cgColor
                label_superview_for_padding.layer.cornerRadius = 10.0
                label_superview_for_padding.layer.masksToBounds = true

                let sender_label = UILabel(frame: CGRect(x: label_superview_for_padding.frame.maxX - 120, y: label_superview_for_padding.frame.maxY - 20, width: 100, height: 40))
                sender_label.text = "  " + sender_email
                sender_label.font = UIFont.boldSystemFont(ofSize: 16)
                sender_label.textColor = UIColor.black
                sender_label.layer.cornerRadius = 10
                sender_label.layer.backgroundColor = UIColor.white.cgColor
                sender_label.layer.shadowColor = UIColor.black.cgColor
                sender_label.layer.shadowOpacity = 0.2
                sender_label.layer.shadowRadius = 1.5
                sender_label.layer.shadowOffset = .zero
                
                label_for_cell.lineBreakMode = .byWordWrapping
                label_for_cell.numberOfLines = 0
                label_for_cell.adjustsFontSizeToFitWidth = true
                label_for_cell.minimumScaleFactor = 0.1
                label_for_cell.text = message_to_render
                label_for_cell.font = UIFont.systemFont(ofSize: 16)
                label_for_cell.textColor = UIColor.black
                label_for_cell.isHidden = false
                cell.contentView.addSubview(label_superview_for_padding)
                label_superview_for_padding.addSubview(label_for_cell)
                label_superview_for_padding.bringSubviewToFront(label_for_cell)
                cell.contentView.bringSubviewToFront(label_for_cell)
                cell.contentView.addSubview(sender_label)
                cell.contentView.bringSubviewToFront(sender_label)
                return cell
            }
            // A video or gif with an mp4 format
            else if(self.keys[indexPath.row].contains(".mp4")){
                var container_for_video_view = UIView(frame: CGRect(x: 20, y: 0, width: self.view.frame.width - 40, height: self.view.frame.width*1.3))
                container_for_video_view.layer.cornerRadius = 10.0
                container_for_video_view.layer.backgroundColor = UIColor.white.cgColor
                container_for_video_view.backgroundColor = UIColor.white
                let data_video = self.meme_container[indexPath.row]
                print(data_video)
                let temp_url = URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("video").appendingPathExtension("mp4")
                let wasFileWritten = (try? data_video.write(to: temp_url, options: [.atomic])) != nil
                if !wasFileWritten{
                    print("File was NOT Written")
                }
                let player = AVPlayer(url: temp_url)
                player.isMuted = true
                let playerViewController = AVPlayerViewController()
                playerViewController.view.layer.cornerRadius = 10.0
                playerViewController.view.backgroundColor = UIColor.white
                playerViewController.player = player
                playerViewController.disableGestureRecognition()
                playerViewController.view.frame = CGRect(x: 20, y: 0, width: self.view.frame.width - 40, height: (self.view.frame.width*1.1))
                let label_superview_for_padding = UIView(frame: CGRect(x: 20, y: playerViewController.view.frame.maxY, width: self.view.frame.width - 40, height: (100)))
                let label_for_cell = UILabel(frame: CGRect(x: 30, y: playerViewController.view.frame.maxY, width: self.view.frame.width - 60, height: (100)))
                
                label_superview_for_padding.layer.backgroundColor = UIColor.white.cgColor
                label_superview_for_padding.layer.cornerRadius = 10.0
                label_superview_for_padding.layer.masksToBounds = true
                
                label_for_cell.lineBreakMode = .byWordWrapping
                label_for_cell.numberOfLines = 0
                label_for_cell.adjustsFontSizeToFitWidth = true
                label_for_cell.minimumScaleFactor = 0.1
                label_for_cell.text = self.captions[indexPath.row] + self.sender_emails[indexPath.row]
                label_for_cell.font = UIFont.systemFont(ofSize: 16)
                label_for_cell.textColor = UIColor.black
                label_for_cell.isHidden = false
                
                let sender_label = UILabel(frame: CGRect(x: label_superview_for_padding.frame.maxX - 120, y: container_for_video_view.frame.maxY, width: 100, height: 40))
                sender_label.text = "  " + self.sender_emails[indexPath.row].prefix(8)
                sender_label.font = UIFont.boldSystemFont(ofSize: 16)
                sender_label.textColor = UIColor.black
                sender_label.layer.cornerRadius = 10
                sender_label.layer.backgroundColor = UIColor.white.cgColor
                sender_label.layer.shadowColor = UIColor.black.cgColor
                sender_label.layer.shadowOpacity = 0.2
                sender_label.layer.shadowRadius = 1.5
                sender_label.layer.shadowOffset = .zero
                
                container_for_video_view.addSubview(playerViewController.view)
                label_superview_for_padding.addSubview(label_for_cell)
                label_for_cell.layoutIfNeeded()
                label_superview_for_padding.layoutIfNeeded()
                cell.contentView.addSubview(container_for_video_view)
                cell.contentView.addSubview(label_superview_for_padding)
                cell.contentView.addSubview(label_for_cell)
                self.addChild(playerViewController)
                playerViewController.didMove(toParent: self)
                cell.contentView.addSubview(playerViewController.view)
                cell.contentView.bringSubviewToFront(playerViewController.view)
                cell.contentView.bringSubviewToFront(label_for_cell)
                cell.contentView.addSubview(sender_label)
                cell.contentView.bringSubviewToFront(sender_label)
                cell.contentView.layoutIfNeeded()
                return cell
            }
            // An image with a caption
            let image_for_cell = UIImage(data: self.meme_container[indexPath.row])
            let container_for_imageview = UIView(frame: CGRect(x: 20, y: 0, width: self.view.frame.width - 40, height: self.view.frame.width*1.3))
            container_for_imageview.backgroundColor = UIColor.white
            container_for_imageview.layer.cornerRadius = 10.0
            let imageview_for_cell = UIImageView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width - 40, height: (self.view.frame.width*1.1)))
            imageview_for_cell.image = image_for_cell
            // within it's container
            // So we have room underneath for the label superview
            imageview_for_cell.contentMode = .scaleAspectFit
            let label_superview_for_padding = UIView(frame: CGRect(x: 20, y: imageview_for_cell.contentClippingRect.minY + imageview_for_cell.contentClippingRect.height, width: self.view.frame.width - 40, height: (100)))
            let label_for_cell = UILabel(frame: CGRect(x: 30, y: imageview_for_cell.contentClippingRect.minY + imageview_for_cell.contentClippingRect.height, width: self.view.frame.width - 60, height: (100)))
            
            label_superview_for_padding.layer.backgroundColor = UIColor.white.cgColor
            label_superview_for_padding.layer.cornerRadius = 10.0
            label_superview_for_padding.layer.masksToBounds = true
            
            label_for_cell.lineBreakMode = .byWordWrapping
            label_for_cell.numberOfLines = 0
            label_for_cell.adjustsFontSizeToFitWidth = true
            label_for_cell.minimumScaleFactor = 0.1
            label_for_cell.text = self.captions[indexPath.row]
            label_for_cell.font = UIFont.systemFont(ofSize: 16)
            label_for_cell.textColor = UIColor.black
            label_for_cell.isHidden = false
            
            container_for_imageview.addSubview(imageview_for_cell)
            label_superview_for_padding.addSubview(label_for_cell)
            label_for_cell.layoutIfNeeded()
            label_superview_for_padding.layoutIfNeeded()
            
            let sender_label = UILabel(frame: CGRect(x: label_superview_for_padding.frame.maxX - 120, y: container_for_imageview.frame.maxY, width: 100, height: 40))
            sender_label.text = "  " + self.sender_emails[indexPath.row].prefix(8)
            sender_label.font = UIFont.boldSystemFont(ofSize: 16)
            sender_label.textColor = UIColor.black
            sender_label.layer.cornerRadius = 10
            sender_label.layer.backgroundColor = UIColor.white.cgColor
            sender_label.layer.shadowColor = UIColor.black.cgColor
            sender_label.layer.shadowOpacity = 0.2
            sender_label.layer.shadowRadius = 1.5
            sender_label.layer.shadowOffset = .zero

            cell.contentView.addSubview(container_for_imageview)
            cell.contentView.addSubview(label_superview_for_padding)
            cell.contentView.addSubview(label_for_cell)
            cell.contentView.addSubview(sender_label)
            label_superview_for_padding.bringSubviewToFront(label_for_cell)
            cell.contentView.bringSubviewToFront(sender_label)
            cell.contentView.layoutIfNeeded()
        }
        else{
            for subview in cell.subviews{
                let casted = subview as! UIImageView
                casted.image = nil
                casted.removeFromSuperview()
            }
        }
        cell.clipsToBounds = true
        // Configure the cell
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        self.collectionView.reloadData()
        if(self.keys[indexPath.row].contains("notameme")){
            return CGSize(width: self.view.frame.width, height: (self.view.frame.width*0.4))
        }
        return CGSize(width: self.view.frame.width, height: (self.view.frame.width*1.42))
    }

    // MARK: UICollectionViewDelegate


    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func loadAllS3MemeNames(){
        let s3 = AWSS3.s3(forKey: "defaultKey")
        let listRequest: AWSS3ListObjectsRequest = AWSS3ListObjectsRequest()
        listRequest.bucket = s3bucket
        listRequest.prefix = self.group! + "/actualmemes/"
        s3.listObjects(listRequest).continueWith { (task) -> AnyObject? in
            let listObjectsOutput = task.result;
            if(task.error != nil || listObjectsOutput == nil || listObjectsOutput?.contents == nil){
                print("No memes found for this group")
                print(task.error)
                return 0 as AnyObject
            }
            // Fill up dictionary with [time, memename]
            // Then fill up an array with the times and sort (most recent comes first)
            // Loop through the time array, access its key name
            // Put this keyname into keys
            // Doing this so the memes appear in order of recency
            var x = 0
            for object in (listObjectsOutput?.contents)! {
                self.modification_times.append(object.lastModified!)
                self.date_to_key[object.lastModified!] = object.key!
                x = x + 1
                if(x == 100){
                    break
                }
            }
            self.modification_times = self.modification_times.sorted(by: self.sortByDate(time1:time2:))
            for date in self.modification_times{
                self.keys.append(self.date_to_key[date]!)
            }
            
            for key in self.keys{
                let queryExpression = AWSDynamoDBQueryExpression()
                queryExpression.keyConditionExpression = "imagepath = :imagepath"
                queryExpression.expressionAttributeValues = [":imagepath": key]
                let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
                let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
                var somefin = dynamoDBObjectMapper.query(Caption.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
                    if (task.error != nil){
                        print("error in querying for Caption")
                        self.captions.append("")
                    }
                    if (task.result != nil){
                        if(task.result?.items.count != 0){
                            let casted = task.result?.items[0] as! Caption
                            self.captions.append(casted.caption as! String)
                            if(casted.userEmail != nil && casted.userEmail != ""){
                                print("printing sender email")
                                print(casted.userEmail)
                                var cut_me_up = casted.userEmail as! String
                                var cut_me_up_list = cut_me_up.components(separatedBy: "@")
                                cut_me_up = cut_me_up_list[0]
                                self.sender_emails.append(cut_me_up)
                            }
                            else{
                                print("not printing sender email")
                                self.sender_emails.append("unknown")
                            }
                        }
                        else{
                            self.captions.append("")
                        }
                    }
                    self.meme_caption_semaphore.signal()
                    return task.result
                }) as! AWSTask<AWSDynamoDBPaginatedOutput>
                self.meme_caption_semaphore.wait()
            }
            self.waitMemeNamesS3.leave()
            return nil
        }
    }
    
    // Comparator used for determining order of messages/memes
    func sortByDate(time1:Date, time2:Date) -> Bool {
      return time1 > time2
    }
    
    @IBAction func open_settings(_ sender: Any) {
        let popup = UIAlertController(title: "Settings", message: "", preferredStyle: .alert)
        let leaveAction = UIAlertAction(title: "Leave Group" , style: .default) { (action) -> Void in
            self.presentMemberLeave()
        }
        let addAction = UIAlertAction(title: "Add Members", style: .default) { (action) -> Void in
            self.getUserEmails()
            self.activityIndicator.startAnimating()
            self.waitUserEmails2.notify(queue: .main){
                self.activityIndicator.stopAnimating()
                self.presentMemberAdd()
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        popup.addAction(leaveAction)
        popup.addAction(addAction)
        popup.addAction(cancelAction)
        self.present(popup, animated: true, completion: nil)
    }
    
    // Used to add new members to group
    func presentMemberAdd() {
        let popup = UIAlertController(title: "Add Members", message: "", preferredStyle: .alert)
        popup.addTextField(configurationHandler: {(textfield: UITextField!) in
            textfield.placeholder = "Member emails (comma separated)"
            self.new_members_textfield = textfield
            self.new_members_textfield.delegate = self
        })
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let saveAction = UIAlertAction(title: "Submit", style: .default) { (action) -> Void in
            print("saved")
            let listy = self.new_members_textfield.text!.components(separatedBy: ",")
            print(listy)
            let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
            let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
            updateMapperConfig.saveBehavior = .updateSkipNullAttributes
            var invalid_users = ""
            self.dispatchQueue.async {
                // FIRST ENSURE EACH EMAIL EXISTS
                // GET THEIR CORRESPONDING SUB
                for user in listy{
                    let queryExpression = AWSDynamoDBQueryExpression()
                    queryExpression.keyConditionExpression = "email = :email"
                    queryExpression.expressionAttributeValues = [":email": String(user)]
                    dynamoDBObjectMapper.query(Email.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
                        if (task.error != nil){
                            print("error in querying for this email")
                            print(task.error)
                        }
                        if (task.result != nil){
                            if(task.result?.items.count == 0){
                                invalid_users.append(" " + String(user))
                                print("We have no emails CollectionView.. likely an incorrect write")
                                print("Should have an alert here")
                                self.adding_user_semaphore.signal()
                            }
                            else{
                                // THIS IS A VALID EMAIL IN THE EMAILS TABLE
                                // LETS FIND ITS CORRESPONDING SUB
                                let casted = task.result?.items[0] as! Email
                                let queryExpression = AWSDynamoDBQueryExpression()
                                queryExpression.keyConditionExpression = "#sub2 = :sub"
                                queryExpression.expressionAttributeValues = [":sub": String(casted.id!)]
                                queryExpression.expressionAttributeNames = ["#sub2": "sub"]
                                self.waitUserSub.enter()
                                let user_sub_match = dynamoDBObjectMapper.query(UserSub.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
                                    if (task.error != nil){
                                        print("error in querying for this sub CollectionView")
                                        print(task.error)
                                        self.waitUserSub.leave()
                                    }
                                    else if (task.result != nil){
                                        self.waitUserSub.leave()
                                    }
                                    return task.result
                                    }) as! AWSTask<AWSDynamoDBPaginatedOutput>

                                self.waitUserSub.notify(queue: .main){
                                    // WE FOUND THE USER WITH THE NOTED SUB
                                    // APPEND THIS NEW GROUP NAME TO THAT USER
                                    // SO THEY CAN ACCESS THE GROUP ON THEIR DEVICE
                                    if(user_sub_match.result?.items.count != 0){
                                        self.casted_user_sub_item = user_sub_match.result?.items[0] as! UserSub
                                        let string_literal = self.group
                                        self.casted_user_sub_item!.updateGroup(group: string_literal!)
                                        print("Attempting to re-write to dynamo user_sub table for " + String(casted.id!))
                                        dynamoDBObjectMapper.save(self.casted_user_sub_item!, configuration: updateMapperConfig).continueWith(block: { (task:AWSTask<AnyObject>!) -> Any? in
                                            if let error = task.error as NSError? {
                                                print("The request failed. Error: \(error)")
                                                self.adding_user_semaphore.signal()
                                            } else {
                                                self.adding_user_semaphore.signal()
                                            }
                                            return 0
                                        })
                                    }
                                    else{
                                       self.adding_user_semaphore.signal()
                                    }
                                }
                            }
                        }
                        return task.result
                    }) as! AWSTask<AWSDynamoDBPaginatedOutput>
                    self.adding_user_semaphore.wait()
                }
                // ONE OF THE USERS ADDED HERE WAS INVALID
                // SHOW AN ALERT SO THEY KNOW
                if(invalid_users.count > 0){
                    DispatchQueue.main.async {
                        let invalid_user_alert = UIAlertController(title: "Invalid User(s)", message: "The following usernames are not in the memedex database and were not added to the new group : " + invalid_users, preferredStyle: .alert)
                        let cancelAction = UIAlertAction(title: "Ok" , style: .cancel)
                        invalid_user_alert.addAction(cancelAction)
                        self.present(invalid_user_alert,animated: true,completion: nil)
                    }
                }
            }
        }
        popup.addAction(cancelAction)
        popup.addAction(saveAction)
        self.present(popup, animated: true, completion: nil)
    }
    
    // Called when a user wants to leave a group
    func presentMemberLeave(){
        let popup = UIAlertController(title: "Leave Group", message: "Are you sure you want to leave this group?", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let leaveAction = UIAlertAction(title: "Leave", style: .default) { (UIAlertAction) in
            self.activityIndicator.startAnimating()
            let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
            let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
            updateMapperConfig.saveBehavior = .updateSkipNullAttributes
            let queryExpression = AWSDynamoDBQueryExpression()
            queryExpression.keyConditionExpression = "#sub2 = :sub"
            var current_user = ""
            if(AppDelegate.socialLoggedIn!){
                current_user = AppDelegate.social_username!
            }
            else{
                current_user = AppDelegate.defaultUserPool().currentUser()?.username as! String
            }
            queryExpression.expressionAttributeValues = [":sub": current_user]
            queryExpression.expressionAttributeNames = ["#sub2": "sub"]
            let temp_dispatch_group = DispatchGroup()
            temp_dispatch_group.enter()
            let user_sub_match = dynamoDBObjectMapper.query(UserSub.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
                if (task.error != nil){
                    print("error in querying for this sub CollectionView")
                    print(task.error)
                    temp_dispatch_group.leave()
                }
                else if (task.result != nil){
                    temp_dispatch_group.leave()
                }
                return task.result
                }) as! AWSTask<AWSDynamoDBPaginatedOutput>
            temp_dispatch_group.notify(queue: .main){
                self.casted_user_sub_item = user_sub_match.result?.items[0] as! UserSub
                let string_literal = self.group
                self.casted_user_sub_item!.removeGroup(group: string_literal!)
                dynamoDBObjectMapper.save(self.casted_user_sub_item!, configuration: updateMapperConfig).continueWith(block: { (task:AWSTask<AnyObject>!) -> Any? in
                    if let error = task.error as NSError? {
                        print("The request failed. Error: \(error)")
                        self.adding_user_semaphore.signal()
                    } else {
                        self.adding_user_semaphore.signal()
                    }
                    DispatchQueue.main.async{
                        self.activityIndicator.stopAnimating()
                        self.performSegue(withIdentifier: "toGroupView", sender: self)
                    }
                    return 0
                })
            }
        }
        popup.addAction(cancelAction)
        popup.addAction(leaveAction)
        self.present(popup, animated: true, completion: nil)
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return !autoCompleteText( in : textField, using: string, suggestionsArray: self.user_emails)
    }
    
    // Auto completes emails
    // To allow for finding other users more easily when creating groups
    // Privacy concern since you could find user emails. Should change eventually
    func autoCompleteText( in textField: UITextField, using string: String, suggestionsArray: [String]) -> Bool {
        if !string.isEmpty,
            let selectedTextRange = textField.selectedTextRange,
            selectedTextRange.end == textField.endOfDocument,
            let prefixRange = textField.textRange(from: textField.beginningOfDocument, to: selectedTextRange.start),
            let text = textField.text( in : prefixRange) {
            let prefix = text + string
            let matches = suggestionsArray.filter {
                $0.hasPrefix(prefix)
            }
            if (matches.count > 0) {
                textField.text = matches[0]
                if let start = textField.position(from: textField.beginningOfDocument, offset: prefix.count) {
                    textField.selectedTextRange = textField.textRange(from: start, to: textField.endOfDocument)
                    return true
                }
            }
        }
        return false
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
    }
    
    func getUserEmails() {
        self.waitUserEmails1.enter()
        let scanExpression = AWSDynamoDBScanExpression()
        let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
        updateMapperConfig.saveBehavior = .updateSkipNullAttributes
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let user_subs = dynamoDBObjectMapper.scan(UserSub.self, expression: scanExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
            if (task.error != nil){
                print("Error scanning for UserSubs in addMemeToGroup before push notification")
                print(task.error)
            }
            if (task.result != nil){
                print("Successfully got user emails for auto-completing group form")
                //print("Successfully scanned user_subs table, about to send notifications to a subset of them")
            }
            self.waitUserEmails1.leave()
            return task.result
        }) as! AWSTask<AWSDynamoDBPaginatedOutput>
        self.waitUserEmails1.notify(queue: .main){
            self.waitUserEmails2.enter()
            self.activityIndicator.stopAnimating()
            let email_container = user_subs.result?.items
            for user in email_container! {
                let casted = user as! UserSub
                self.user_emails.append(casted.email as! String)
            }
            self.waitUserEmails2.leave()
        }
    }
    
    
    

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    
    }
    */

}

// Use this to get the edges of an actual image in an imageview
extension UIImageView {
    var contentClippingRect: CGRect {
        guard let image = image else { return bounds }
        guard contentMode == .scaleAspectFit else { return bounds }
        guard image.size.width > 0 && image.size.height > 0 else { return bounds }

        let scale: CGFloat
        if image.size.width > image.size.height {
            scale = bounds.width / image.size.width
        } else {
            scale = bounds.height / image.size.height
        }

        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let x = (bounds.width - size.width) / 2.0
        let y = (bounds.height - size.height) / 2.0

        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}

