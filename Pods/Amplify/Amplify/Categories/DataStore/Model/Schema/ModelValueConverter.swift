//
// Copyright 2018-2020 Amazon.com,
// Inc. or its affiliates. All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Establishes how `Model` fields should be converted to and from different targets (e.g. SQL and GraphQL).
public protocol ModelValueConverter {

    /// The base type on the source (i.e. the `Model` property type)
    associatedtype SourceType

    /// The type on the target (i.e. the `SQL` value type)
    associatedtype TargetType

    /// Converts a source value of a certain type to the target type
    ///
    /// - Parameters:
    ///   - source: the value from the `Model`
    ///   - fieldType: the type of the `Model` field
    /// - Returns: the converted value
    static func convertToTarget(from source: SourceType, fieldType: ModelFieldType) throws -> TargetType

    /// Converts a target value of a certain type to the `Model` field type
    ///
    /// - Parameters:
    ///   - target: the value from the target
    ///   - fieldType: the type of the `Model` field
    /// - Returns: the converted value to the expected `ModelFieldType`
    static func convertToSource(from target: TargetType, fieldType: ModelFieldType) throws -> SourceType

}

/// Extension with reusable JSON encoding/decoding utilities.
extension ModelValueConverter {

    static var jsonDecoder: JSONDecoder {
        JSONDecoder(dateDecodingStrategy: ModelDateFormatting.decodingStrategy)
    }

    static var jsonEncoder: JSONEncoder {
        JSONEncoder(dateEncodingStrategy: ModelDateFormatting.encodingStrategy)
    }

    public static func toJSON(_ value: Encodable) throws -> String? {
        let data = try jsonEncoder.encode(value.eraseToAnyEncodable())
        return String(data: data, encoding: .utf8)
    }

    public static func fromJSON(_ value: String) throws -> Any? {
        guard let data = value.data(using: .utf8) else {
            return nil
        }
        return try JSONSerialization.jsonObject(with: data)
    }
}
