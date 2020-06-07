//
//  PartnerMatches.swift
//  memedex
//
//  Created by meagh054 on 4/25/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import AWSDynamoDB

// Used for finding potential partners
// A partner is someone whose meme ratings help identify memes
// For the current user
class PartnerMatches: AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    @objc var username:NSString?
    @objc var user1:NSString?
    @objc var user2:NSString?
    @objc var user3:NSString?
    @objc var user4:NSString?
    @objc var user5:NSString?
    @objc var user6:NSString?
    @objc var user7:NSString?
    @objc var user8:NSString?
    @objc var user9:NSString?
    @objc var user10:NSString?
    
    class func dynamoDBTableName() -> String {
        return "user_matchings"
    }
    
    class func hashKeyAttribute() -> String {
        return "username"
    }
    
    func setUsers(users: [(key:String,value:Double)]) {
        var count = 0
        for user in users{
            switch count {
            case 0:
                self.user1 = (user.0 as NSString)
            case 1:
                self.user2 = (user.0 as NSString)
            case 2:
                self.user3 = (user.0 as NSString)
            case 3:
                self.user4 = (user.0 as NSString)
            case 4:
                self.user5 = (user.0 as NSString)
            case 5:
                self.user6 = (user.0 as NSString)
            case 6:
                self.user7 = (user.0 as NSString)
            case 7:
                self.user8 = (user.0 as NSString)
            case 8:
                self.user9 = (user.0 as NSString)
            case 9:
                self.user10 = (user.0 as NSString)
            default:
                print("more users than we need")
                return
            }
            count = count + 1
        }
    }
    
    func printUsers() {
        print(self.user1 ?? " ")
        print(self.user2 ?? " ")
        print(self.user3 ?? " ")
        print(self.user4 ?? " ")
        print(self.user5 ?? " ")
        print(self.user6 ?? " ")
        print(self.user7 ?? " ")
        print(self.user8 ?? " ")
        print(self.user9 ?? " ")
        print(self.user10 ?? " ")
    }
    
    func getUsers() -> [String] {
        var listy = [String]()
        if self.user1 != nil && self.user1 != ""{
            listy.append(self.user1! as String)
        }
        if self.user2 != nil && self.user2 != ""{
            listy.append(self.user2! as String)
        }
        if self.user3 != nil && self.user3 != ""{
            listy.append(self.user3! as String)
        }
        if self.user4 != nil && self.user4 != ""{
            listy.append(self.user4! as String)
        }
        if self.user5 != nil && self.user5 != ""{
            listy.append(self.user5! as String)
        }
        if self.user6 != nil && self.user6 != ""{
            listy.append(self.user6! as String)
        }
        if self.user7 != nil && self.user7 != ""{
            listy.append(self.user7! as String)
        }
        if self.user8 != nil && self.user8 != ""{
            listy.append(self.user8! as String)
        }
        if self.user9 != nil && self.user9 != ""{
            listy.append(self.user9! as String)
        }
        if self.user10 != nil && self.user10 != ""{
            listy.append(self.user10! as String)
        }
        return listy
    }
}
