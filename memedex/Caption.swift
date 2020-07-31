//
//  Caption.swift
//  memedex
//
//  Created by meagh054 on 7/30/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import AWSDynamoDB

class Caption: AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    @objc var imagepath:NSString?
    @objc var caption:NSString?
    
    class func dynamoDBTableName() -> String {
        return "captions"
    }
    
    class func hashKeyAttribute() -> String {
        return "imagepath"
    }
}
