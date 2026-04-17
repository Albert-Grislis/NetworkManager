//
//  NetworkAliases.swift
//
//
//  Created by Albert Grislis on 13.02.2021.
//

import Foundation

// MARK: Public typealiases
public typealias MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType> = (
    success: (Result<ResponseType, ErrorType>) -> Void,
    failure: ((Result<ResponseType, Error>) -> Void)?
) where ResponseType: Decodable, ErrorType: Error & Decodable
public typealias RawNetworkRequestCompletionHandler = (Result<Data, Error>) -> Void
