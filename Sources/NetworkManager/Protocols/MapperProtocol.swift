//
//  MapperProtocol.swift
//  NetworkManager
//
//  Created by Albert Grislis on 25.12.2021.
//

import Foundation

@preconcurrency
public protocol MapperProtocol: Sendable {
    func map<ResponseType>(data: Data) throws -> ResponseType where ResponseType: Decodable
}
