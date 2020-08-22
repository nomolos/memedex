//
//  Meme.swift
//  memedex
//
//  Created by meagh054 on 4/6/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import AWSDynamoDB

class Meme: AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    @objc var username:NSString?
    @objc var rating:NSNumber?
    @objc var meme:NSString?
    @objc var link:NSString?
    
    class func dynamoDBTableName() -> String {
        return "users2"
    }

    class func hashKeyAttribute() -> String {
        return "username"
    }
    
    class func rangeKeyAttribute() -> String {
        return "meme"
    }
}
