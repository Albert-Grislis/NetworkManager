//
//  StubError.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

enum StubError {
    case mapping
    case rejected
}

// MARK: Error
extension StubError: Error { /* EMPTY */ }
