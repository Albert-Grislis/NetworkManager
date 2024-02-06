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
    private func startTrackingAndPerform(
        operation: RawNetworkOperation,
        forKey urlRequest: URLRequest
    ) {
        operation.completionBlock = { [weak self] in
            self?._operations.mutate { (operations) in
                operations.removeValue(forKey: urlRequest)
            }
        }
        self._operations.mutate { (operations) in
            operations.updateValue(
                operation,
                forKey: urlRequest
            )
        }
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
        if let mappedNetworkOperation = self.operations[urlRequest] as? MappedNetworkOperation<ResponseType> {
            mappedNetworkOperation.mergeCompletionHandlers(contentsOf: [completionHandlerQueue: [completionHandler]])
        } else {
            let mappedNetworkOperation = MappedNetworkOperation(
                urlRequest: urlRequest,
                urlSession: self.urlSession,
                progressObserver: progressObserver,
                mapper: mapper,
                mappedDataCompletionHandlersHashTable: [completionHandlerQueue: [completionHandler]]
            )
            self.startTrackingAndPerform(
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
        if let rawNetworkOperation = self.operations[urlRequest] {
            rawNetworkOperation.mergeCompletionHandlers(contentsOf: [completionHandlerQueue: [completionHandler]])
        } else {
            let rawNetworkOperation = RawNetworkOperation(
                urlRequest: urlRequest,
                urlSession: self.urlSession,
                progressObserver: progressObserver,
                completionHandlersHashTable: [completionHandlerQueue: [completionHandler]]
            )
            self.startTrackingAndPerform(
                operation: rawNetworkOperation,
                forKey: urlRequest
            )
        }
    }
    
    public func cancelAnyTasksIfNeeded(at urlRequest: URLRequest) {
        self.operations.removeValue(forKey: urlRequest)?.cancel()
    }
}
