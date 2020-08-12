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

private let reuseIdentifier = "Cell"

class CollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {

    var meme_container = [Data]()
    var keys = [String]()
    var captions = [String]()
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
    let test_textfield = UITextField()
    //let waitMessageSend = DispatchGroup()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.activityIndicator = UIActivityIndicatorView()
        self.activityIndicator.color = UIColor.gray
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
        /*DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.activityIndicator.stopAnimating()
        }*/

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes
        self.collectionView.translatesAutoresizingMaskIntoConstraints = false
        self.collectionView.isHidden = false
        self.collectionView.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor).isActive = true
        self.collectionView!.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        self.collectionView.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor, constant: 30).isActive = true
        self.collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -70).isActive = true
        
        var textfield_container = UIView()
        self.view.addSubview(textfield_container)
        textfield_container.widthAnchor.constraint(equalTo: self.view.widthAnchor).isActive = true
        textfield_container.heightAnchor.constraint(equalToConstant: 100).isActive = true
        textfield_container.topAnchor.constraint(equalTo: self.collectionView.bottomAnchor, constant: -10).isActive = true
        textfield_container.backgroundColor = UIColor.white
        //self.view.addSubview(textfield_container)
        textfield_container.addSubview(test_textfield)
        
        test_textfield.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        test_textfield.widthAnchor.constraint(equalTo: self.view.widthAnchor, constant: -40).isActive = true
        test_textfield.topAnchor.constraint(equalTo: self.collectionView.bottomAnchor).isActive = true
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
        //self.collectionView.bottomAnchor.constraint(equalTo: test_textfield.bottomAnchor, constant: -150).isActive = true
        // Do any additional setup after loading the view.
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
        //self.waitMessageSend.enter()
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
        let message = self.test_textfield.text?.data(using: .utf8)
        let randy = self.randomString(length: 20)
        //let randy_data = randy.
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
                //self.collectionView.reloadData()
            }
            //self.waitMessageSend.leave()
            return nil
        }
        self.test_textfield.text = ""
        dismissKeyboard()
        self.view.frame.origin.y = 0
        /*self.waitMessageSend.notify(queue: .main){
            print("should be refreshing.. prolly broken")
            self.waitMemeNamesS3.enter()
            self.loadAllS3MemeNames()
        }*/
        //self.key
        print("should be reloading data")
        self.keys.insert((self.group! + "/actualmemes/notameme/" + randy), at: 0)
        self.meme_container.insert(message!, at: 0)
        // Prevents captions from crashing due to
        // indicies not lining up with meme_container and keys
        self.captions.insert("", at:0)
        DispatchQueue.main.async{
            self.collectionView.reloadData()
            self.collectionView.layoutIfNeeded()
            self.view.layoutIfNeeded()
            self.activityIndicator.stopAnimating()
        }
    }
    
    func randomString(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map{ _ in letters.randomElement()! })
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

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
//        for subview in cell.subviews{
//            subview.removeFromSuperview()
//        }
        if(indexPath.row < self.meme_container.count){
            for subview in cell.contentView.subviews{
                subview.removeFromSuperview()
            }
            print("printing our key value at this index")
            print(self.keys[indexPath.row])
            
            if(self.keys[indexPath.row].contains("notameme")){
                print("this is a message not a meme")
                let message_to_render = String(decoding: self.meme_container[indexPath.row], as: UTF8.self)
                print(message_to_render)
                let label_superview_for_padding = UIView(frame: CGRect(x: 20, y: cell.contentView.frame.minY + 20, width: self.view.frame.width - 40, height: (100)))
                let label_for_cell = UILabel(frame: CGRect(x: 30, y: cell.contentView.frame.minY, width: self.view.frame.width - 60, height: (100)))
                
                label_superview_for_padding.layer.backgroundColor = UIColor.white.cgColor
                label_superview_for_padding.layer.cornerRadius = 10.0
                label_superview_for_padding.layer.masksToBounds = true
                label_superview_for_padding.layer.borderWidth = 1
                label_superview_for_padding.layer.borderColor = UIColor.lightGray.cgColor
                
                label_for_cell.lineBreakMode = .byWordWrapping
                label_for_cell.numberOfLines = 0
                label_for_cell.adjustsFontSizeToFitWidth = true
                label_for_cell.minimumScaleFactor = 0.1
                label_for_cell.text = message_to_render
                label_for_cell.font = UIFont.systemFont(ofSize: 20)
                label_for_cell.textColor = UIColor.black
                label_for_cell.isHidden = false
                cell.contentView.addSubview(label_superview_for_padding)
                label_superview_for_padding.addSubview(label_for_cell)
                label_superview_for_padding.bringSubviewToFront(label_for_cell)
                cell.contentView.bringSubviewToFront(label_for_cell)
                /*cell.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 200)
                cell.contentView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 200)
                cell.setNeedsDisplay()
                cell.contentView.setNeedsDisplay()
                print("printing cell info")
                print(cell.frame)
                print(cell.contentView.frame)
                print(self.view.frame)*/
                return cell
            }
            
            let image_for_cell = UIImage(data: self.meme_container[indexPath.row])
            var container_for_imageview = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.width*1.1))
            var imageview_for_cell = UIImageView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: (self.view.frame.width*1.1)))
            imageview_for_cell.image = image_for_cell
            // within it's container
            // So we have room underneath for the label superview
            imageview_for_cell.contentMode = .scaleAspectFit
            let label_superview_for_padding = UIView(frame: CGRect(x: 20, y: imageview_for_cell.contentClippingRect.minY + imageview_for_cell.contentClippingRect.height + 20, width: self.view.frame.width - 40, height: (100)))
            let label_for_cell = UILabel(frame: CGRect(x: 30, y: imageview_for_cell.contentClippingRect.minY + imageview_for_cell.contentClippingRect.height + 20, width: self.view.frame.width - 60, height: (100)))
            
            label_superview_for_padding.layer.backgroundColor = UIColor.white.cgColor
            label_superview_for_padding.layer.cornerRadius = 10.0
            label_superview_for_padding.layer.masksToBounds = true
            label_superview_for_padding.layer.borderWidth = 1
            label_superview_for_padding.layer.borderColor = UIColor.lightGray.cgColor
            
            label_for_cell.lineBreakMode = .byWordWrapping
            label_for_cell.numberOfLines = 0
            label_for_cell.adjustsFontSizeToFitWidth = true
            label_for_cell.minimumScaleFactor = 0.1
            label_for_cell.text = self.captions[indexPath.row]
            label_for_cell.font = UIFont.systemFont(ofSize: 20)
            label_for_cell.textColor = UIColor.black
            label_for_cell.isHidden = false
            
            container_for_imageview.addSubview(imageview_for_cell)
            label_superview_for_padding.addSubview(label_for_cell)
            label_for_cell.layoutIfNeeded()
            label_superview_for_padding.layoutIfNeeded()
            cell.contentView.addSubview(container_for_imageview)
            cell.contentView.addSubview(label_superview_for_padding)
            cell.contentView.addSubview(label_for_cell)
            label_superview_for_padding.bringSubviewToFront(label_for_cell)
            cell.contentView.layoutIfNeeded()
            
            
            label_superview_for_padding.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor, constant:0).isActive = true
            label_for_cell.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor, constant:0).isActive = true
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
                print("PRINTING ERROR LOADING S3 MEMES")
                print(task.error)
                DispatchQueue.main.sync{
                    let alert = UIAlertController(title: "No Memes Right Now", message: "memedex is currently searching the internet for the latest memes. Usually this happens around 12AM Central Time (US) and lasts 20 minutes", preferredStyle: .alert)
                    self.present(alert, animated: true)
                }
                return nil
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
                //print(String(object.key!))
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
                            print("Caption result is ")
                            print(task.result?.items[0])
                            let casted = task.result?.items[0] as! Caption
                            self.captions.append(casted.caption as! String)
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
    
    func sortByDate(time1:Date, time2:Date) -> Bool {
      return time1 > time2
    }
    
    @IBAction func open_settings(_ sender: Any) {
        let popup = UIAlertController(title: "Settings", message: "", preferredStyle: .alert)
        let leaveAction = UIAlertAction(title: "Leave Group" , style: .default) { (action) -> Void in
            self.presentMemberLeave()
        }
        let addAction = UIAlertAction(title: "Add Members", style: .default) { (action) -> Void in
            print("add members")
            self.presentMemberAdd()
            print("popup should have added textfield")
            
           //validation logic goes here
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        popup.addAction(leaveAction)
        popup.addAction(addAction)
        popup.addAction(cancelAction)
        self.present(popup, animated: true, completion: nil)
    }
    
    func presentMemberAdd() {
        let popup = UIAlertController(title: "Add Members", message: "", preferredStyle: .alert)
        popup.addTextField(configurationHandler: {(textfield: UITextField!) in
            textfield.placeholder = "Member emails (comma separated)"
            self.new_members_textfield = textfield
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
                            print("printing result in email query (adding user to group)")
                            print(task.result?.items)
                            if(task.result?.items.count == 0){
                                invalid_users.append(" " + String(user))
                                print("We have no emails.. likely an incorrect write")
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
                                        print("error in querying for this sub")
                                        print(task.error)
                                        self.waitUserSub.leave()
                                        //self.adding_user_semaphore.signal()
                                    }
                                    else if (task.result != nil){
                                        print("successfully queried for this sub")
                                        print(task.result?.items)
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
                                                print("Saved new user sub to dynamo")
                                                print(task.result)
                                                //print(task.result?.item)
                                                // print(task.result?.items)
                                                self.adding_user_semaphore.signal()
                                                // Do something with task.result or perform other operations.
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
    
    func presentMemberLeave(){
        let popup = UIAlertController(title: "Leave Group", message: "Are you sure you want to leave this group?", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        let leaveAction = UIAlertAction(title: "Leave", style: .default) { (UIAlertAction) in
            print("implement leave code here")
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
                    print("error in querying for this sub")
                    print(task.error)
                    temp_dispatch_group.leave()
                    //self.adding_user_semaphore.signal()
                }
                else if (task.result != nil){
                    print("successfully queried for this sub")
                    print(task.result?.items)
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
                        print("Saved new user sub to dynamo")
                        print(task.result)
                        //print(task.result?.item)
                        // print(task.result?.items)
                        self.adding_user_semaphore.signal()
                        // Do something with task.result or perform other operations.
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


