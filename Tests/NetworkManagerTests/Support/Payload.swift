//
//  Payload.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

struct Payload {

    // MARK: Internal properties
    let value: String
}

// MARK: Decodable
extension Payload: Decodable { /* EMPTY */ }

// MARK: Equatable
extension Payload: Equatable { /* EMPTY */ }
