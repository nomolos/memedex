//
//  Group.swift
//  memedex
//
//  Created by meagh054 on 7/22/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import AWSDynamoDB

class Group: AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    @objc var group_name:NSString?
    @objc var usernames = [NSString]()
    
    class func dynamoDBTableName() -> String {
        return "groups"
    }
    
    class func hashKeyAttribute() -> String {
        return "group_name"
    }
    
    func set_usernames(unparsed: String){
        let listy = unparsed.components(separatedBy: ",")
        print(listy)
        self.usernames = listy as [NSString]
    }
}
