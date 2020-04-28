//
//  GoldenMeme.swift
//  memedex
//
//  Created by meagh054 on 4/23/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import AWSDynamoDB


class GoldenMeme: AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    @objc var username:NSString?
    @objc var rating:NSNumber?
    @objc var meme:NSString?
    
    class func dynamoDBTableName() -> String {
        return "users_golden"
    }

    class func hashKeyAttribute() -> String {
        return "username"
    }
    
    class func rangeKeyAttribute() -> String {
        return "meme"
    }
}
