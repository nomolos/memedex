//
//  TopSources.swift
//  memedex
//
//  Created by meagh054 on 7/5/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import AWSDynamoDB

class TopSources: AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    @objc var username:NSString?
    @objc var first:NSString?
    @objc var second:NSString?
    @objc var third:NSString?
        
    class func dynamoDBTableName() -> String {
        return "user_top_sources"
    }

    class func hashKeyAttribute() -> String {
        return "username"
    }
}
