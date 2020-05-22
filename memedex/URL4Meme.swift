//
//  URL4Meme.swift
//  memedex
//
//  Created by meagh054 on 5/22/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import AWSDynamoDB

class URL4Meme: AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    @objc var memename:NSString?
    @objc var URL:NSString?
    
    class func dynamoDBTableName() -> String {
        return "URLs"
    }
    
    class func hashKeyAttribute() -> String {
        return "memename"
    }
}
