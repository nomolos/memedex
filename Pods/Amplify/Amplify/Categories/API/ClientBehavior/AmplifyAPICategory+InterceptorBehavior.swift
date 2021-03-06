//
// Copyright 2018-2020 Amazon.com,
// Inc. or its affiliates. All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

extension AmplifyAPICategory: APICategoryInterceptorBehavior {

    public func add(interceptor: URLRequestInterceptor, for apiName: String) throws {
        try plugin.add(interceptor: interceptor, for: apiName)
    }

}
