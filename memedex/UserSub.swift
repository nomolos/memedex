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
    @objc var groups = [NSString]()
    
    class func dynamoDBTableName() -> String {
        return "user_subs"
    }
    
    func updateGroup(group:String){
        if(groups == nil || groups.count == 0){
            self.groups = [(group as NSString)]
        }
        else{
            self.groups.append(group as NSString)
        }
    }
    
    func removeGroup(group:String){
        var count = 0
        for group2 in self.groups{
            if(group == (group2 as String)){
                self.groups.remove(at: count)
            }
            count = count + 1
        }
    }
    
    class func hashKeyAttribute() -> String {
        return "sub"
    }
}
