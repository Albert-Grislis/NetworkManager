//
//  DecodingError+MissingKey.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

extension DecodingError {

    // MARK: Internal properties
    var missingKey: String? {
        guard case let .keyNotFound(key, _) = self else { return nil }
        return key.stringValue
    }
}
