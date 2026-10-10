//
//  Delivery.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

struct Delivery<Value> where Value: Sendable {

    // MARK: Internal properties
    let value: Value
    let queueLabel: String
}
