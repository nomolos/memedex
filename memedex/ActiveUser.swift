//
//  ActiveUser.swift
//  memedex
//
//  Created by meagh054 on 4/24/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import AWSDynamoDB

class ActiveUser: AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    @objc var username:NSString?
    
    class func dynamoDBTableName() -> String {
        return "users_active_today"
    }
    
    class func hashKeyAttribute() -> String {
        return "username"
    }
}
