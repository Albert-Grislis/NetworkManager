//
//  RejectingError.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

struct RejectingError {
    /* EMPTY */
}

// MARK: Error
extension RejectingError: Error { /* EMPTY */ }

// MARK: Decodable
extension RejectingError: Decodable {
    init(from decoder: Decoder) throws {
        throw StubError.rejected
    }
}
