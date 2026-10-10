//
//  NetworkAliases.swift
//  NetworkManager
//
//  Created by Albert Grislis on 13.02.2021.
//

import Foundation

// MARK: Public typealiases
public typealias MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType> = (
    success: @Sendable (Result<ResponseType, ErrorType>) -> Void,
    failure: (@Sendable (Result<ResponseType, Error>) -> Void)?
) where ResponseType: Decodable, ErrorType: Error & Decodable
public typealias RawNetworkRequestCompletionHandler = @Sendable (Result<Data, Error>) -> Void
