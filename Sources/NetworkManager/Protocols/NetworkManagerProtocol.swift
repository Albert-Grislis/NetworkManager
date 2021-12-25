//
//  NetworkManagerProtocol.swift
//
//
//  Created by Albert Grislis on 14.04.2021.
//

import Foundation

public protocol NetworkManagerProtocol {
    
    // MARK: Public methods
    func mappedData<ResponseType>(url: URL,
                                  mapper: MapperProtocol,
                                  completionHandlerQueue: DispatchQueue,
                                  completionHandler: @escaping MappedNetworkRequestCompletionHandler<ResponseType>) where ResponseType: Decodable

    func mappedData<ResponseType>(url: URL,
                                  mapper: MapperProtocol,
                                  completionHandlerQueue: DispatchQueue,
                                  completionHandler: @escaping MappedNetworkRequestCompletionHandler<ResponseType>,
                                  progressObserver: NetworkOperationProgressObservationProtocol?) where ResponseType: Decodable
    
    func mappedData<ResponseType>(urlRequest: URLRequest,
                                  mapper: MapperProtocol,
                                  completionHandlerQueue: DispatchQueue,
                                  completionHandler: @escaping MappedNetworkRequestCompletionHandler<ResponseType>) where ResponseType: Decodable

    func mappedData<ResponseType>(urlRequest: URLRequest,
                                  mapper: MapperProtocol,
                                  completionHandlerQueue: DispatchQueue,
                                  completionHandler: @escaping MappedNetworkRequestCompletionHandler<ResponseType>,
                                  progressObserver: NetworkOperationProgressObservationProtocol?) where ResponseType: Decodable

    func rawData(url: URL,
                 completionHandlerQueue: DispatchQueue,
                 completionHandler: @escaping RawNetworkRequestCompletionHandler)

    func rawData(url: URL,
                 completionHandlerQueue: DispatchQueue,
                 completionHandler: @escaping RawNetworkRequestCompletionHandler,
                 progressObserver: NetworkOperationProgressObservationProtocol?)

    func rawData(urlRequest: URLRequest,
                 completionHandlerQueue: DispatchQueue,
                 completionHandler: @escaping RawNetworkRequestCompletionHandler)
    
    func rawData(urlRequest: URLRequest,
                 completionHandlerQueue: DispatchQueue,
                 completionHandler: @escaping RawNetworkRequestCompletionHandler,
                 progressObserver: NetworkOperationProgressObservationProtocol?)

    func cancelAnyTasksIfNeeded(at urlRequest: URLRequest)
}
