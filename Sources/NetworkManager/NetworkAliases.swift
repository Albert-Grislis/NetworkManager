//
//  NetworkAliases.swift
//
//
//  Created by Albert Grislis on 13.02.2021.
//

import Foundation

// MARK: Public typealiases
public typealias MappedNetworkRequestCompletionHandler<ResponseType> = (Result<ResponseType, Error>) -> Void where ResponseType: Decodable
public typealias RawNetworkRequestCompletionHandler = (Result<Data, Error>) -> Void
