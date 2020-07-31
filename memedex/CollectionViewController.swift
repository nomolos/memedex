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
                        print("printing data collection view")
                        print(data)
                        //print(task)
                        //print(url)
                        //print(task.result)
                        //print(data)
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
            //self.collectionView.reloadData()
        }
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes
        self.collectionView!.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)

        // Do any additional setup after loading the view.
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
        print("printing index path row")
        print(indexPath.row)
        if(indexPath.row < self.meme_container.count){
            for subview in cell.contentView.subviews{
                subview.removeFromSuperview()
            }
            let image_for_cell = UIImage(data: self.meme_container[indexPath.row])
            var imageview_for_cell = UIImageView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: (self.view.frame.width*1.42)))
            imageview_for_cell.image = image_for_cell
            let textfield_for_cell = UITextField(frame: CGRect(x: 10, y: imageview_for_cell.frame.maxY - 60, width: self.view.frame.width, height: (self.view.frame.width/5)))
            textfield_for_cell.text = self.captions[indexPath.row]
            textfield_for_cell.font = UIFont.systemFont(ofSize: 20)
            
//            if(Float((image_for_cell?.size.width)!) > Float((image_for_cell?.size.height)!)){
//                imageview_for_cell.contentMode = .scaleAspectFit
//            }
//            else{
//                imageview_for_cell.contentMode = .scaleAspectFill
//            }
            
            imageview_for_cell.contentMode = .scaleAspectFit
            cell.contentView.addSubview(imageview_for_cell)
            cell.contentView.addSubview(textfield_for_cell)
            //textfield_for_cell.topAnchor = imageview_for_cell
            //cell.imageV
            //cell.co
        }
        else{
            for subview in cell.subviews{
                let casted = subview as! UIImageView
                casted.image = nil
                casted.removeFromSuperview()
            }
        }
        //cell.cont
        //cell.clipsToBounds = true
        //cell.contentMode = .scaleAspectFit
        cell.clipsToBounds = true
        // Configure the cell
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        print("in this size function")
        self.collectionView.reloadData()
        return CGSize(width: self.view.frame.width, height: (self.view.frame.width*1.42))
    }

    // MARK: UICollectionViewDelegate


    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        print("in highlighted")
        return true
    }

    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        print("in selected")
        return true
    }
    
    func loadAllS3MemeNames(){
        let s3 = AWSS3.s3(forKey: "defaultKey")
        let listRequest: AWSS3ListObjectsRequest = AWSS3ListObjectsRequest()
        listRequest.bucket = s3bucket
        print("printing prefix")
        listRequest.prefix = self.group! + "/actualmemes/"
        print(listRequest.prefix)
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
            var x = 0
            for object in (listObjectsOutput?.contents)! {
                print("printing key")
                print(object.key)
                print("printing modification time")
                print(object.lastModified)
                self.modification_times.append(object.lastModified!)
                self.date_to_key[object.lastModified!] = object.key!
                //self.keys.append(String(object.key!))
                print("sizes should be equal")
                print(self.modification_times.count)
                print(self.keys.count)
                x = x + 1
                if(x == 100){
                    break
                }
                //print(String(object.key!))
            }
            print("pre-sort")
            print("pre-sort")
            print(self.modification_times)
            print("attempting to sort dates")
            print("attempting to sort dates")
            self.modification_times = self.modification_times.sorted(by: self.sortByDate(time1:time2:))
            print(self.modification_times)
            for date in self.modification_times{
                self.keys.append(self.date_to_key[date]!)
            }
            
            for key in self.keys{
                print("END OF LOAD ALL MEMES, CHECKING DYNAMO")
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
            print("printing captions")
            print(self.captions)
            self.waitMemeNamesS3.leave()
            return nil
        }
    }
    
    func sortByDate(time1:Date, time2:Date) -> Bool {
      return time1 > time2
    }
    
    @IBAction func open_settings(_ sender: Any) {
        let popup = UIAlertController(title: "Settings", message: "", preferredStyle: .alert)
        let leaveAction = UIAlertAction(title: "Leave Group" , style: .destructive)
        let addAction = UIAlertAction(title: "Add Members", style: .default) { (action) -> Void in
            print("add members")
           //validation logic goes here
        }
        let changeAction = UIAlertAction(title: "Change Group Name", style: .default) { (action) -> Void in
            print("change group name")
           //validation logic goes here
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        popup.addAction(leaveAction)
        popup.addAction(addAction)
        popup.addAction(changeAction)
        popup.addAction(cancelAction)
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

