//
//  NetworkManagerProtocol.swift
//
//
//  Created by Albert Grislis on 14.04.2021.
//

import Foundation

public protocol NetworkManagerProtocol {
    
    // MARK: Public methods
    func rawData(url: URL,
                 completionHandlerQueue: DispatchQueue,
                 completionHandler: @escaping NetworkCompletionHandler,
                 progressObserver: NetworkOperationProgressObservationProtocol?)
    func rawData(urlRequest: URLRequest,
                 completionHandlerQueue: DispatchQueue,
                 completionHandler: @escaping NetworkCompletionHandler,
                 progressObserver: NetworkOperationProgressObservationProtocol?)
    func cancelAnyTasksIfNeeded(at urlRequest: URLRequest)
}
