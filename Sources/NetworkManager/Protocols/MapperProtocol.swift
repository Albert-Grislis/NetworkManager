//
//  MapperProtocol.swift
//  
//
//  Created by Albert Grislis on 25.12.2021.
//

import Foundation

public protocol MapperProtocol {
    func map<ResponseType>(data: Data) throws -> ResponseType where ResponseType: Decodable
}
