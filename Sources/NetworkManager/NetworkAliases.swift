//
//  NetworkAliases.swift
//  
//
//  Created by Albert Grislis on 13.02.2021.
//

import Foundation

// MARK: Public typealiases
public typealias Response = (data: Data, statusCode: Int)
public typealias NetworkCompletionHandler = (Result<Response, Error>) -> Void
