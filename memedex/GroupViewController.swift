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

class GroupViewController: UITableViewController {

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
    
    @IBAction func add_group(_ sender: Any) {
        let popup = UIAlertController(title: "New Group", message: "", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "Cancel" , style: .cancel)
        let saveAction = UIAlertAction(title: "Submit", style: .default) { (action) -> Void in
            self.group_names.append(self.new_group_textfield.text!)
            self.group_member_count.append(1)
            print("Our group members should be " + self.new_group_users_textfield.text!)
            self.tableView.reloadData  ()
            let group = Group()
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
                            print("printing result in email query (group creation)")
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
                                print("Should be appending a sub")
                                print(casted)
                                print("Appending this : ")
                                print(casted.id)
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
                                        print("THIS IS WHAT WE'RE UPDATING WITH")
                                        print(self.new_group_textfield.text)
                                        let string_literal = self.new_group_textfield.text as! String
                                        self.casted_user_sub_item!.updateGroup(group: string_literal)
                                        print("This is the new object")
                                        print(self.casted_user_sub_item)
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
                    print("successfully queried for this sub")
                    print(task.result?.items)
                    self.waitOurSub.leave()
                }
                return task.result
            }) as! AWSTask<AWSDynamoDBPaginatedOutput>
            self.waitOurSub.notify(queue: .main){
                var casted_user_sub_item2 = user_sub_match2.result?.items[0] as! UserSub
                let string_literal = self.new_group_textfield.text as! String
                casted_user_sub_item2.updateGroup(group: string_literal)
                dynamoDBObjectMapper.save(casted_user_sub_item2, configuration: updateMapperConfig).continueWith(block: { (task:AWSTask<AnyObject>!) -> Any? in
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
            // ADDING THIS PARTICULAR USER TO THE GROUP
            // CURRENT USER SEPARATE FROM EMAILS ENTERED
            
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
        })
        self.present(popup, animated: true, completion: nil)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //SET UP THE RIGHT BAR BUTTON
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
        //SET UP THE RIGHT BAR BUTTON
        
        
        print("In viewDidLoad GroupViewController")
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
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.group_names.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "groupCell", for: indexPath)
        cell.textLabel!.text = self.group_names[indexPath.row]
        //cell.contentView.backgroundColor = UIColor(red: 0.71, green: 0.44, blue: 0.95, alpha: 1.00)
        if(self.group_member_count[indexPath.row] == 1){
            cell.detailTextLabel!.text = String(self.group_member_count[indexPath.row]) + " Member"
        }
        else{
            cell.detailTextLabel!.text = String(self.group_member_count[indexPath.row]) + " Members"
        }
        
        // Configure the cell...

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
                print("printing result in loadOurGroupNames GroupViewController")
                print(task.result?.items)
                if(task.result?.items.count == 0){
                    print("We have no items in loadOurGroupNames GroupViewController, there was no element at this user's sub")
                    return task.result
                }
            }
            print("leaving waitOurGroups")
            self.waitOurGroups.leave()
            return task.result
        }) as! AWSTask<AWSDynamoDBPaginatedOutput>
        
        self.waitOurGroups.notify(queue: .main){
            let queryExpression2 = AWSDynamoDBQueryExpression()
            let dynamoDBObjectMapper2 = AWSDynamoDBObjectMapper.default()
            let updateMapperConfig2 = AWSDynamoDBObjectMapperConfiguration()
            updateMapperConfig2.saveBehavior = .updateSkipNullAttributes
            print("notified that we got our group info")
            if(user_sub_response.result?.items.count == 0){
                print("ERROR NO USER FOUND loadOurGroupNames GroupViewController")
                return
            }
            let casted_user_sub = user_sub_response.result?.items[0] as! UserSub
            if(casted_user_sub.groups == nil || casted_user_sub.groups.count == 0){
                print("No groups for this user")
                self.waitOurGroupsMemberCount.leave()
                return
            }
            self.dispatchQueue.async {
                for group in casted_user_sub.groups{
                    print("iterating over " + (group as String))
                    self.group_names.append(group as String)
                    queryExpression2.keyConditionExpression = "group_name = :group_name"
                    queryExpression2.expressionAttributeValues = [":group_name":(group as String)]
                    print("about to query for this groups info")
                    print(queryExpression2.keyConditionExpression)
                    print(queryExpression2.expressionAttributeValues)
                    print(queryExpression2.projectionExpression)
                    var group_response_info = dynamoDBObjectMapper.query(Group.self, expression: queryExpression2).continueWith(executor: AWSExecutor.mainThread(), block: { (task:AWSTask<AWSDynamoDBPaginatedOutput>) -> Any? in
                        print("inside the query")
                        if (task.error != nil){
                            print("error in loadOurGroupNames GroupViewController Gathering Group Info")
                            print(task.error)
                        }
                        else if (task.result != nil){
                            print("printing result in loadOurGroupNames GroupViewController Gathering Group Info")
                            print(task.result?.items)
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
                    print("waiting")
                    self.group_info_semaphore.wait()
                }
                self.waitOurGroupsMemberCount.leave()
            }
        }
    }
    
    /*func loadOurGroupMemberCounts() {
        
    }*/

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

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if(segue.identifier == "toCollection"){
            let collection_view = segue.destination as! CollectionViewController
            let cell = sender as! UITableViewCell
            print("assinging our collection views group to be : " + (cell.textLabel?.text)!)
            collection_view.group = cell.textLabel!.text
            // Get the new view controller using segue.destination.
            // Pass the selected object to the new view controller.
        }
    }
    
    
    @IBAction func backToView(_ sender: Any) {
        print("IN BACKTOVIEW")
        //print(self.casted_user_sub_item)
        DispatchQueue.main.async{
            //self.dismiss(animated: true, completion: nil)
            let hacky_scene_access = UIApplication.shared.connectedScenes.first
            let scene_delegate = hacky_scene_access?.delegate as! SceneDelegate
            scene_delegate.viewController?.fromGroups = true
            //scene_delegate.navigationController?.dis
            //self.dismiss(animated: true, completion: nil)
            //scene_delegate.navigationController?.popViewController(animated: true)
            scene_delegate.navigationController?.setViewControllers([scene_delegate.viewController!], animated: true)
            //self.removeFromParent()
        }
    }
    
}
