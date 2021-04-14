//
//  NetworkManagerProtocol.swift
//  
//
//  Created by Albert Grislis on 14.04.2021.
//

import Foundation

public protocol NetworkManagerProtocol {
    func rawData(urlRequest: URLRequest,
                 completionHandlerQueue: DispatchQueue,
                 completionHandler: @escaping NetworkCompletionHandler,
                 progressObserver: NetworkOperationProgressObservationProtocol?)
    func cancelAnyTasksIfNeeded(at urlRequest: URLRequest)
}
