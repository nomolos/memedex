//
//  SNSEndpoint.swift
//  memedex
//
//  Created by meagh054 on 8/11/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import AWSDynamoDB

class SNSEndpoint: AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    @objc var sub:NSString?
    @objc var endpoint:NSString?
    
    class func dynamoDBTableName() -> String {
        return "sns_endpoints"
    }
    
    class func hashKeyAttribute() -> String {
        return "sub"
    }
    
    
}
