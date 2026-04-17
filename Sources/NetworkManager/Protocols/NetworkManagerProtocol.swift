//
//  NetworkManagerProtocol.swift
//
//
//  Created by Albert Grislis on 14.04.2021.
//

import Foundation

public protocol NetworkManagerProtocol {
    
    // MARK: Public methods
    func mappedData<ResponseType, ErrorType>(
        url: URL,
        mapper: MapperProtocol,
        completionHandlerQueue: DispatchQueue,
        completionHandlers: MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType>
    ) where ResponseType: Decodable, ErrorType: Error & Decodable
    
    func mappedData<ResponseType, ErrorType>(
        url: URL,
        mapper: MapperProtocol,
        completionHandlerQueue: DispatchQueue,
        completionHandlers: MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType>,
        progressObserver: NetworkOperationProgressObservationProtocol?
    ) where ResponseType: Decodable, ErrorType: Error & Decodable
    
    func mappedData<ResponseType, ErrorType>(
        urlRequest: URLRequest,
        mapper: MapperProtocol,
        completionHandlerQueue: DispatchQueue,
        completionHandlers: MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType>
    ) where ResponseType: Decodable, ErrorType: Error & Decodable
    
    func mappedData<ResponseType, ErrorType>(
        urlRequest: URLRequest,
        mapper: MapperProtocol,
        completionHandlerQueue: DispatchQueue,
        completionHandlers: MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType>,
        progressObserver: NetworkOperationProgressObservationProtocol?
    ) where ResponseType: Decodable, ErrorType: Error & Decodable
    
    func rawData(
        url: URL,
        completionHandlerQueue: DispatchQueue,
        completionHandler: @escaping RawNetworkRequestCompletionHandler
    )
    
    func rawData(
        url: URL,
        completionHandlerQueue: DispatchQueue,
        completionHandler: @escaping RawNetworkRequestCompletionHandler,
        progressObserver: NetworkOperationProgressObservationProtocol?
    )
    
    func rawData(
        urlRequest: URLRequest,
        completionHandlerQueue: DispatchQueue,
        completionHandler: @escaping RawNetworkRequestCompletionHandler
    )
    
    func rawData(
        urlRequest: URLRequest,
        completionHandlerQueue: DispatchQueue,
        completionHandler: @escaping RawNetworkRequestCompletionHandler,
        progressObserver: NetworkOperationProgressObservationProtocol?
    )
    
    func cancelAnyTasksIfNeeded(at urlRequest: URLRequest)
}
