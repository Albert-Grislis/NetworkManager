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
    @UnfairLock private var operations: [URLRequest: RawNetworkOperation]
    private let operationQueue: OperationQueue
    private let urlSession: URLSession
    
    // MARK: Initializers & Deinitializers
    public init(
        urlSession: URLSession,
        qualityOfServiceOfOperationQueue: QualityOfService
    ) {
        self.operations = [:]
        self.operationQueue = OperationQueue()
        self.operationQueue.qualityOfService = qualityOfServiceOfOperationQueue
        self.urlSession = urlSession
        super.init()
    }
    
    // MARK: Private methods
    private func createRemovingCompletionHandler(with urlRequest: URLRequest) -> RawNetworkRequestCompletionHandler {
        return { [weak self] _ in
            self?.operations.removeValue(forKey: urlRequest)
        }
    }
    
    private func createRemovingCompletionHandler<ResponseType>(with urlRequest: URLRequest) -> MappedNetworkRequestCompletionHandler<ResponseType> where ResponseType: Decodable {
        return { [weak self] _ in
            self?.operations.removeValue(forKey: urlRequest)
        }
    }
    
    private func startTrackingAndThenPerform(
        operation: RawNetworkOperation,
        forKey urlRequest: URLRequest
    ) {
        self.operations.updateValue(
            operation,
            forKey: urlRequest
        )
        self.operationQueue.addOperation(operation)
    }
}

// MARK: NetworkManagerProtocol
extension NetworkManager: NetworkManagerProtocol {
    public func mappedData<ResponseType>(
        url: URL,
        mapper: MapperProtocol,
        completionHandlerQueue: DispatchQueue,
        completionHandler: @escaping MappedNetworkRequestCompletionHandler<ResponseType>
    ) where ResponseType: Decodable {
        mappedData(
            url: url,
            mapper: mapper,
            completionHandlerQueue: completionHandlerQueue,
            completionHandler: completionHandler,
            progressObserver: nil
        )
    }
    
    public func mappedData<ResponseType>(
        url: URL,
        mapper: MapperProtocol,
        completionHandlerQueue: DispatchQueue,
        completionHandler: @escaping MappedNetworkRequestCompletionHandler<ResponseType>,
        progressObserver: NetworkOperationProgressObservationProtocol?
    ) where ResponseType: Decodable {
        let urlRequest = URLRequest(url: url)
        mappedData(
            urlRequest: urlRequest,
            mapper: mapper,
            completionHandlerQueue: completionHandlerQueue,
            completionHandler: completionHandler,
            progressObserver: progressObserver
        )
    }
    
    public func mappedData<ResponseType>(
        urlRequest: URLRequest,
        mapper: MapperProtocol,
        completionHandlerQueue: DispatchQueue,
        completionHandler: @escaping MappedNetworkRequestCompletionHandler<ResponseType>
    ) where ResponseType: Decodable {
        mappedData(
            urlRequest: urlRequest,
            mapper: mapper,
            completionHandlerQueue: completionHandlerQueue,
            completionHandler: completionHandler,
            progressObserver: nil
        )
    }
    
    public func mappedData<ResponseType>(
        urlRequest: URLRequest,
        mapper: MapperProtocol,
        completionHandlerQueue: DispatchQueue,
        completionHandler: @escaping MappedNetworkRequestCompletionHandler<ResponseType>,
        progressObserver: NetworkOperationProgressObservationProtocol?
    ) where ResponseType: Decodable {
        // RemovingCompletionHandler is always last in the MappedNetworkOperation.mappedNetowrkRequestCompletionHandlers property to avoid overhead of CPU and memory usage
        let removingCompletionHandler: MappedNetworkRequestCompletionHandler<ResponseType> = self.createRemovingCompletionHandler(with: urlRequest)
        if let mappedNetworkOperation = self.operations[urlRequest] as? MappedNetworkOperation<ResponseType> {
            mappedNetworkOperation.removeLastCompletionHandler()
            mappedNetworkOperation.appendCompletionHandlers(contentsOf: [completionHandler, removingCompletionHandler])
        } else {
            let mappedNetworkOperation = MappedNetworkOperation(
                urlSession: self.urlSession,
                urlRequest: urlRequest,
                mapper: mapper,
                completionHandlersQueue: completionHandlerQueue,
                mappedNetworkRequestCompletionHandlers: [completionHandler, removingCompletionHandler],
                progressObserver: progressObserver
            )
            self.startTrackingAndThenPerform(
                operation: mappedNetworkOperation,
                forKey: urlRequest
            )
        }
    }
    
    public func rawData(
        url: URL,
        completionHandlerQueue: DispatchQueue,
        completionHandler: @escaping RawNetworkRequestCompletionHandler
    ) {
        self.rawData(
            url: url,
            completionHandlerQueue: completionHandlerQueue,
            completionHandler: completionHandler,
            progressObserver: nil
        )
    }
    
    public func rawData(
        urlRequest: URLRequest,
        completionHandlerQueue: DispatchQueue,
        completionHandler: @escaping RawNetworkRequestCompletionHandler
    ) {
        self.rawData(
            urlRequest: urlRequest,
            completionHandlerQueue: completionHandlerQueue,
            completionHandler: completionHandler,
            progressObserver: nil
        )
    }
    
    public func rawData(
        url: URL,
        completionHandlerQueue: DispatchQueue,
        completionHandler: @escaping RawNetworkRequestCompletionHandler,
        progressObserver: NetworkOperationProgressObservationProtocol?
    ) {
        let urlRequest = URLRequest(url: url)
        self.rawData(
            urlRequest: urlRequest,
            completionHandlerQueue: completionHandlerQueue,
            completionHandler: completionHandler,
            progressObserver: progressObserver
        )
    }
    
    public func rawData(
        urlRequest: URLRequest,
        completionHandlerQueue: DispatchQueue,
        completionHandler: @escaping RawNetworkRequestCompletionHandler,
        progressObserver: NetworkOperationProgressObservationProtocol?
    ) {
        // RemovingCompletionHandler is always last in the RawNetworkOperation.completionHandlers property to avoid overhead of CPU and memory usage
        let removingCompletionHandler: RawNetworkRequestCompletionHandler = self.createRemovingCompletionHandler(with: urlRequest)
        if let rawNetworkOperation = self.operations[urlRequest] {
            rawNetworkOperation.removeLastCompletionHandler()
            rawNetworkOperation.appendCompletionHandlers(contentsOf: [completionHandler, removingCompletionHandler])
        } else {
            let rawNetworkOperation = RawNetworkOperation(
                urlSession: self.urlSession,
                urlRequest: urlRequest,
                completionHandlersQueue: completionHandlerQueue,
                rawNetowrkRequestCompletionHandlers: [completionHandler, removingCompletionHandler],
                progressObserver: progressObserver
            )
            self.startTrackingAndThenPerform(
                operation: rawNetworkOperation,
                forKey: urlRequest
            )
        }
    }
    
    public func cancelAnyTasksIfNeeded(at urlRequest: URLRequest) {
        self.operations[urlRequest]?.cancel()
        self.operations.removeValue(forKey: urlRequest)
    }
}
