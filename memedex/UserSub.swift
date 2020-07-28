//
//  UserSub.swift
//  memedex
//
//  Created by meagh054 on 7/27/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import AWSDynamoDB

class UserSub: AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    @objc var sub:NSString?
    @objc var email:NSString?
    @objc var groups:[NSString]?
    
    class func dynamoDBTableName() -> String {
        return "user_subs"
    }
    
    func updateGroup(group:String){
        self.groups?.append(group as NSString)
    }
    
    class func hashKeyAttribute() -> String {
        return "sub"
    }
}
