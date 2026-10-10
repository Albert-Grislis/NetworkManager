//
//  ServerError.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

struct ServerError {

    // MARK: Internal properties
    let code: Int
    let message: String
}

// MARK: Error
extension ServerError: Error { /* EMPTY */ }

// MARK: Decodable
extension ServerError: Decodable { /* EMPTY */ }

// MARK: Equatable
extension ServerError: Equatable { /* EMPTY */ }
