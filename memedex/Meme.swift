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
    @objc var sub:String?
    @objc var rating:NSNumber?
    
    class func dynamoDBTableName() -> String {
        return "users"
    }

    class func hashKeyAttribute() -> String {
        return "sub"
    }
}
