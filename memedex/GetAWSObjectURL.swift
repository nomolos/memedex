//
//  GetAWSObjectURL.swift
//  memedex
//
//  Created by meagh054 on 4/16/20.
//  Copyright © 2020 solomon. All rights reserved.
//

import UIKit
import Foundation
import AWSS3

// This whole class lets us make a URL
// To host videos at
// So we can play the video from this URL

let S3BucketName = "memedexbucket"
class GetAWSObjectURL: NSObject {
    
    var preSignedURLString = ""

    func getPreSignedURL( S3DownloadKeyName: String)->String{
        let getPreSignedURLRequest = AWSS3GetPreSignedURLRequest()
        getPreSignedURLRequest.httpMethod = AWSHTTPMethod.GET
        getPreSignedURLRequest.key = S3DownloadKeyName
        getPreSignedURLRequest.bucket = S3BucketName
        getPreSignedURLRequest.expires = Date(timeIntervalSinceNow: 3600)
        
        AWSS3PreSignedURLBuilder.default().getPreSignedURL(getPreSignedURLRequest).continueWith { (task:AWSTask<NSURL>) -> Any? in
            if let error = task.error as NSError? {
                print("Error: \(error)")
                return nil
            }
            self.preSignedURLString = (task.result?.absoluteString)!
            return nil
        }
        return self.preSignedURLString
    }
}
