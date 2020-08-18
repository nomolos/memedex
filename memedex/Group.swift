//
//  Group.swift
//  memedex
//
//  Created by meagh054 on 7/22/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import AWSDynamoDB

class Group: AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    @objc var group_name:NSString?
    @objc var usernames = [NSString]()
    
    class func dynamoDBTableName() -> String {
        return "groups"
    }
    
    class func hashKeyAttribute() -> String {
        return "group_name"
    }
    
    func set_usernames(unparsed: String){
        // Get rid of any commas or whitespace in the usernames
        var listy = unparsed.components(separatedBy: ",")
        if(listy.count == 1){
            let maybe_they_used_spaces = listy[0]
            listy = maybe_they_used_spaces.components(separatedBy: " ")
        }
        var county = 0
        while county < listy.count{
            listy[county] = listy[county].trimmingCharacters(in: .whitespacesAndNewlines)
            county = county + 1
        }
        print("Group class usernames")
        print(listy)
        self.usernames = listy as [NSString]
    }
}
