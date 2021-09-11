//
//  NetworkManager.swift
//
//
//  Created by Albert Grislis on 13.02.2021.
//

import Foundation
import Utils

public final class NetworkManager: NSObject {
    
    // MARK: Private properties
    @UnfairLock private var operations: [URLRequest: NetworkOperation]
    private let operationQueue: OperationQueue
    private let urlSession: URLSession
    
    // MARK: Initializers & Deinitializers
    public init(urlSession: URLSession) {
        self.operations = [:]
        self.operationQueue = OperationQueue()
        self.operationQueue.qualityOfService = .userInitiated
        self.urlSession = urlSession
        super.init()
    }
    
    // MARK: Private methods
    private func createRemovingCompletionHandler(with urlRequest: URLRequest) -> NetworkCompletionHandler {
        return { [weak self] _ in
            self?.operations.removeValue(forKey: urlRequest)
        }
    }
}

// MARK: NetworkManagerProtocol
extension NetworkManager: NetworkManagerProtocol {
    public func rawData(url: URL,
                        completionHandlerQueue: DispatchQueue,
                        completionHandler: @escaping NetworkCompletionHandler) {
        self.rawData(url: url,
                     completionHandlerQueue: completionHandlerQueue,
                     completionHandler: completionHandler,
                     progressObserver: nil)
    }

    public func rawData(urlRequest: URLRequest,
                        completionHandlerQueue: DispatchQueue,
                        completionHandler: @escaping NetworkCompletionHandler) {
        self.rawData(urlRequest: urlRequest,
                     completionHandlerQueue: completionHandlerQueue,
                     completionHandler: completionHandler,
                     progressObserver: nil)
    }

    public func rawData(url: URL,
                        completionHandlerQueue: DispatchQueue,
                        completionHandler: @escaping NetworkCompletionHandler,
                        progressObserver: NetworkOperationProgressObservationProtocol?) {
        let urlRequest = URLRequest(url: url)
        self.rawData(urlRequest: urlRequest,
                     completionHandlerQueue: completionHandlerQueue,
                     completionHandler: completionHandler,
                     progressObserver: progressObserver)
    }
    
    public func rawData(urlRequest: URLRequest,
                        completionHandlerQueue: DispatchQueue,
                        completionHandler: @escaping NetworkCompletionHandler,
                        progressObserver: NetworkOperationProgressObservationProtocol?) {
        // RemovingCompletionHandler is always last in the NetworkOperation.completionHandlers property to avoid overhead of CPU and memory usage
        let removingCompletionHandler = self.createRemovingCompletionHandler(with: urlRequest)
        if let networkOperation = self.operations[urlRequest] {
            networkOperation.removeLastCompletionHandler()
            networkOperation.appendCompletionHandlers(contentsOf: [completionHandler, removingCompletionHandler])
        } else {
            let networkOperation = NetworkOperation(urlSession: self.urlSession,
                                                    urlRequest: urlRequest,
                                                    completionHandlersQueue: completionHandlerQueue,
                                                    completionHandlers: [completionHandler, removingCompletionHandler],
                                                    progressObserver: progressObserver)
            self.operations.updateValue(networkOperation, forKey: urlRequest)
            self.operationQueue.addOperation(networkOperation)
        }
    }
    
    public func cancelAnyTasksIfNeeded(at urlRequest: URLRequest) {
        self.operations[urlRequest]?.cancel()
        self.operations.removeValue(forKey: urlRequest)
    }
}
