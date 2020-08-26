//
//  GroupViewController.swift
//  memedex
//
//  Created by meagh054 on 7/19/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import AWSCognito
import AWSCognitoIdentityProvider
import AWSCore
import AWSDynamoDB
import AVKit
import AVFoundation
import Amplify

class GroupViewController: UITableViewController, UITextFieldDelegate {

    var group_names = [String]()
    var group_member_count = [Int]()
    var new_group_textfield:UITextField!
    var new_group_users_textfield:UITextField!
    let adding_user_semaphore = DispatchSemaphore(value: 0)
    let group_info_semaphore = DispatchSemaphore(value: 0)
    let dispatchQueue = DispatchQueue(label: "com.queue.Serial")
    let waitUserSub = DispatchGroup()
    let waitOurSub = DispatchGroup()
    let waitOurGroups = DispatchGroup()
    let waitOurGroupsMemberCount = DispatchGroup()
    var casted_user_sub_item:UserSub?
    var activityIndicator = UIActivityIndicatorView()
    var waitUserEmailsGroupCreation = DispatchGroup()
    var user_emails = [String]()
    var user_email:String?
    
    // Create new group
    @IBAction func add_group(_ sender: Any) {
        self.activityIndicator.startAnimating()
        self.waitUserEmailsGroupCreation.enter()
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
            self.waitUserEmailsGroupCreation.leave()
            return task.result
        }) as! AWSTask<AWSDynamoDBPaginatedOutput>
        self.waitUserEmailsGroupCreation.notify(queue: .main){
            self.activityIndicator.stopAnimating()
            let email_container = user_subs.result?.items
            for user in email_container! {
                let casted = user as! UserSub
                self.user_emails.append(casted.email as! String)
            }
            let popup = UIAlertController(title: "New Group", message: "", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Cancel" , style: .cancel)
            let saveAction = UIAlertAction(title: "Submit", style: .default) { (action) -> Void in
                self.group_names.append(self.new_group_textfield.text!)
                self.group_member_count.append(1)
                self.tableView.reloadData  ()
                let group = Group()
                // Should eventually display an alert
                if(self.new_group_users_textfield.text! == ""){
                    let no_user_popup = UIAlertController(title: "Find another memedex user", message: "Add someone else to make a group :)", preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "Ok", style: .default)
                    no_user_popup.addAction(okAction)
                    self.present(no_user_popup, animated: true, completion: nil)
                    return
                }
                group?.set_usernames(unparsed: self.new_group_users_textfield.text!)
                group?.group_name = self.new_group_textfield.text as NSString?
                let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
                let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
                updateMapperConfig.saveBehavior = .updateSkipNullAttributes
                var invalid_users = ""
                self.dispatchQueue.async {
                    // FIRST ENSURE EACH EMAIL EXISTS
                    // GET THEIR CORRESPONDING SUB
                    var count = 0
                    for user in group!.usernames{
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
                                    print("We have no emails.. likely an incorrect write")
                                    print("Should have an alert here eventually")
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
                                            let string_literal = self.new_group_textfield.text as! String
                                            self.casted_user_sub_item!.updateGroup(group: string_literal)
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
                // THE GROUPS TABLE STILL HOLDS THE INVALID USERS
                // MIGHT WANT TO EVENTUALLY CHANGE THAT
                dynamoDBObjectMapper.save(group!, configuration: updateMapperConfig).continueWith(block: { (task:AWSTask<AnyObject>!) -> Any? in
                    if let error = task.error as NSError? {
                        print("The request failed. Error: \(error)")
                    } else {
                        // Do something with task.result or perform other operations.
                    }
                    return 0
                })
                
                // ADDING THIS PARTICULAR USER TO THE GROUP
                // CURRENT USER SEPARATE FROM EMAILS ENTERED
                var our_sub = ""
                if(AppDelegate.socialLoggedIn!){
                    print("social logged in")
                    our_sub = AppDelegate.social_username!
                }
                else{
                    print("No social login, printing regular username")
                    our_sub = AppDelegate.defaultUserPool().currentUser()?.username as! String
                }
                let queryExpression = AWSDynamoDBQueryExpression()
                queryExpression.keyConditionExpression = "#sub2 = :sub"
                queryExpression.expressionAttributeValues = [":sub": our_sub]
                queryExpression.expressionAttributeNames = ["#sub2": "sub"]
                self.waitOurSub.enter()
                let user_sub_match2 = dynamoDBObjectMapper.query(UserSub.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
                    if (task.error != nil){
                        print("error in querying for this sub")
                        print(task.error)
                        self.waitOurSub.leave()
                    }
                    else if (task.result != nil){
                        self.waitOurSub.leave()
                    }
                    return task.result
                }) as! AWSTask<AWSDynamoDBPaginatedOutput>
                self.waitOurSub.notify(queue: .main){
                    print("self.waitOurSub.notify")
                    if((user_sub_match2.result?.items.count)! > 0){
                        var casted_user_sub_item2 = user_sub_match2.result?.items[0] as! UserSub
                        let string_literal = self.new_group_textfield.text as! String
                        casted_user_sub_item2.updateGroup(group: string_literal)
                        dynamoDBObjectMapper.save(casted_user_sub_item2, configuration: updateMapperConfig).continueWith(block: { (task:AWSTask<AnyObject>!) -> Any? in
                            if let error = task.error as NSError? {
                                print("The request failed. Error: \(error)")
                                self.adding_user_semaphore.signal()
                            } else {
                                self.adding_user_semaphore.signal()
                            }
                            return 0
                        })
                    }
                }  
            }
            popup.addAction(cancelAction)
            popup.addAction(saveAction)
            popup.addTextField(configurationHandler: {(textfield: UITextField!) in
                textfield.placeholder = "Group name"
                self.new_group_textfield = textfield
            })
            popup.addTextField(configurationHandler: {(textfield: UITextField!) in
                textfield.placeholder = "Member emails (comma separated)"
                self.new_group_users_textfield = textfield
                self.new_group_users_textfield.delegate = self
            })
            self.present(popup, animated: true, completion: nil)
        }
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
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let rightButton = UIButton(type: .custom)
        rightButton.frame = CGRect(x: 0.0, y: 0.0, width: 27.0, height: 27.0)
        rightButton.setImage(UIImage(named:"addToGroup"), for: .normal)
        rightButton.addTarget(self, action: #selector(add_group(_:)), for: UIControl.Event.touchUpInside)
        let rightBarItem = UIBarButtonItem(customView: rightButton)
        let currWidth = rightBarItem.customView?.widthAnchor.constraint(equalToConstant: 27)
        currWidth?.isActive = true
        let currHeight = rightBarItem.customView?.heightAnchor.constraint(equalToConstant: 27)
        currHeight?.isActive = true
        self.navigationItem.rightBarButtonItem = rightBarItem
        self.activityIndicator = UIActivityIndicatorView()
        self.activityIndicator.color = UIColor.white
        self.activityIndicator.style = UIActivityIndicatorView.Style.large
        self.activityIndicator.frame = CGRect(x: self.view.bounds.midX - 50, y: self.view.bounds.midY - 100, width: 100, height: 100)
        self.activityIndicator.hidesWhenStopped = true
        self.activityIndicator.layer.zPosition = 1
        self.tableView.addSubview(self.activityIndicator)
        self.activityIndicator.startAnimating()
        self.waitOurGroups.enter()
        self.waitOurGroupsMemberCount.enter()
        self.loadOurGroupNames()
        self.waitOurGroupsMemberCount.notify(queue: .main){
            self.tableView.reloadData()
            self.activityIndicator.stopAnimating()
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.group_names.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "groupCell", for: indexPath)
        cell.textLabel!.text = self.group_names[indexPath.row]
        if(self.group_member_count[indexPath.row] == 1){
            cell.detailTextLabel!.text = String(self.group_member_count[indexPath.row]) + " Member"
        }
        else{
            cell.detailTextLabel!.text = String(self.group_member_count[indexPath.row]) + " Members"
        }
        return cell
    }
    
    func loadOurGroupNames() {
        let queryExpression = AWSDynamoDBQueryExpression()
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        let updateMapperConfig = AWSDynamoDBObjectMapperConfiguration()
        updateMapperConfig.saveBehavior = .updateSkipNullAttributes
        queryExpression.keyConditionExpression = "#sub2 = :sub"
        queryExpression.expressionAttributeNames = ["#sub2": "sub"]
        if(AppDelegate.socialLoggedIn!){
            queryExpression.expressionAttributeValues = [":sub": AppDelegate.social_username]
            print("[in loadOurGroupNames GroupViewController], our user's sub is : " + AppDelegate.social_username!)
        }
        else{
            queryExpression.expressionAttributeValues = [":sub": AppDelegate.defaultUserPool().currentUser()?.username]
            print("[in loadOurGroupNames GroupViewController], our user's sub is : " + (AppDelegate.defaultUserPool().currentUser()?.username)!)
        }
        var user_sub_response = dynamoDBObjectMapper.query(UserSub.self, expression: queryExpression).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
            if (task.error != nil){
                print("error in loadOurGroupNames GroupViewController")
                print(task.error)
            }
            else if (task.result != nil){
                if(task.result?.items.count == 0){
                    print("We have no items in loadOurGroupNames GroupViewController, there was no element at this user's sub")
                    return task.result
                }
            }
            self.waitOurGroups.leave()
            return task.result
        }) as! AWSTask<AWSDynamoDBPaginatedOutput>
        
        self.waitOurGroups.notify(queue: .main){
            let queryExpression2 = AWSDynamoDBQueryExpression()
            let dynamoDBObjectMapper2 = AWSDynamoDBObjectMapper.default()
            let updateMapperConfig2 = AWSDynamoDBObjectMapperConfiguration()
            updateMapperConfig2.saveBehavior = .updateSkipNullAttributes
            if(user_sub_response.result?.items.count == 0){
                print("ERROR NO USER FOUND loadOurGroupNames GroupViewController")
                return
            }
            let casted_user_sub = user_sub_response.result?.items[0] as! UserSub
            if(casted_user_sub.groups == nil || casted_user_sub.groups.count == 0){
                print("No groups for this user")
                DispatchQueue.main.async{
                    let no_group_popup = UIAlertController(title: "No Groups Yet", message: "Click the plus button to make your first group", preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "Ok", style: .default)
                    no_group_popup.addAction(okAction)
                    self.present(no_group_popup, animated: true, completion: nil)
                }
                self.waitOurGroupsMemberCount.leave()
                return
            }
            self.dispatchQueue.async {
                for group in casted_user_sub.groups{
                    self.group_names.append(group as String)
                    queryExpression2.keyConditionExpression = "group_name = :group_name"
                    queryExpression2.expressionAttributeValues = [":group_name":(group as String)]
                    var group_response_info = dynamoDBObjectMapper.query(Group.self, expression: queryExpression2).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
                        //print("inside the query")
                        if (task.error != nil){
                            print("error in loadOurGroupNames GroupViewController Gathering Group Info")
                            print(task.error)
                        }
                        else if (task.result != nil){
                            if(task.result?.items.count == 0){
                                print("We have no items in loadOurGroupNames GroupViewController Gathering Group Info, there was no element at this Group")
                                return task.result
                            }
                            else{
                                let casted_group = task.result?.items[0] as! Group
                                self.group_member_count.append(casted_group.usernames.count)
                            }
                        }
                        self.group_info_semaphore.signal()
                        return task.result
                    }) as! AWSTask<AWSDynamoDBPaginatedOutput>
                    self.group_info_semaphore.wait()
                }
                self.user_email = casted_user_sub.email as! String
                self.waitOurGroupsMemberCount.leave()
            }
        }
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    // MARK: - Navigation

    // Heading to collection view for the group we selected
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if(segue.identifier == "toCollection"){
            let collection_view = segue.destination as! CollectionViewController
            let cell = sender as! UITableViewCell
            print("assinging our collection views group to be : " + (cell.textLabel?.text)!)
            collection_view.group = cell.textLabel!.text
            collection_view.user_email = self.user_email
            // Get the new view controller using segue.destination.
            // Pass the selected object to the new view controller.
        }
    }
    
    // Heading to ViewController
    @IBAction func backToView(_ sender: Any) {
        DispatchQueue.main.async{
            let hacky_scene_access = UIApplication.shared.connectedScenes.first
            let scene_delegate = hacky_scene_access?.delegate as! SceneDelegate
            scene_delegate.viewController?.fromGroups = true
            scene_delegate.navigationController?.setViewControllers([scene_delegate.viewController!], animated: true)
        }
    }
    
}
