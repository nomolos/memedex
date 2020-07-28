//
//  Email.swift
//  memedex
//
//  Created by meagh054 on 7/23/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import AWSDynamoDB

class Email: AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    @objc var email:NSString?
    @objc var id:NSString?
    
    class func dynamoDBTableName() -> String {
        return "emails"
    }
    
    class func hashKeyAttribute() -> String {
        return "email"
    }
}
