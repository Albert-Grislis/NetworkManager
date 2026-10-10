//
//  NetworkManager.swift
//  NetworkManager
//
//  Created by Albert Grislis on 13.02.2021.
//

import Foundation
import Utils

public final class NetworkManager: NSObject {
    
    // MARK: Private properties
    @UnfairLock private var operations: [OperationKey: RawNetworkOperation]
    @UnfairLock private var displacedOperations: [OperationKey: [RawNetworkOperation]]
    private let operationQueue: OperationQueue
    private let urlSession: URLSession
    private let synchronizationQueue = DispatchQueue(label: "com.networkmanager.synchronization")
    
    // MARK: Initializers & Deinitializers
    public init(
        urlSession: URLSession,
        qualityOfServiceOfOperationQueue: QualityOfService
    ) {
        self.operations = [:]
        self.displacedOperations = [:]
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
        let operationKey = OperationKey(urlRequest: urlRequest)
        operation.completionBlock = { [weak self, weak operation] in
            guard let self, let operation else { return }
            self.synchronizationQueue.sync {
                self._operations.mutate { (operations) in
                    guard operations[operationKey] === operation else { return }
                    operations.removeValue(forKey: operationKey)
                }
                self._displacedOperations.mutate { (displacedOperations) in
                    displacedOperations[operationKey]?.removeAll { (displacedOperation) in
                        displacedOperation === operation
                    }
                    if displacedOperations[operationKey]?.isEmpty == true {
                        displacedOperations.removeValue(forKey: operationKey)
                    }
                }
            }
        }
        let displacedOperation = self._operations.mutate { (operations) in
            operations.updateValue(
                operation,
                forKey: operationKey
            )
        }
        if let displacedOperation {
            self._displacedOperations.mutate { (displacedOperations) in
                displacedOperations[operationKey, default: []].append(displacedOperation)
            }
        }
        self.operationQueue.addOperation(operation)
    }
}

// MARK: NetworkManagerProtocol
extension NetworkManager: NetworkManagerProtocol {    
    public func mappedData<ResponseType, ErrorType>(
        url: URL,
        mapper: MapperProtocol,
        completionHandlerQueue: DispatchQueue,
        completionHandlers: MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType>
    ) where ResponseType: Decodable & Sendable, ErrorType: Error & Decodable {
        self.mappedData(
            url: url,
            mapper: mapper,
            completionHandlerQueue: completionHandlerQueue,
            completionHandlers: completionHandlers,
            progressObserver: nil
        )
    }
    
    public func mappedData<ResponseType, ErrorType>(
        url: URL,
        mapper: MapperProtocol,
        completionHandlerQueue: DispatchQueue,
        completionHandlers: MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType>,
        progressObserver: NetworkOperationProgressObservationProtocol?
    ) where ResponseType: Decodable & Sendable, ErrorType: Error & Decodable {
        let urlRequest = URLRequest(url: url)
        self.mappedData(
            urlRequest: urlRequest,
            mapper: mapper,
            completionHandlerQueue: completionHandlerQueue,
            completionHandlers: completionHandlers,
            progressObserver: progressObserver
        )
    }
    
    public func mappedData<ResponseType, ErrorType>(
        urlRequest: URLRequest,
        mapper: MapperProtocol,
        completionHandlerQueue: DispatchQueue,
        completionHandlers: MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType>
    ) where ResponseType: Decodable & Sendable, ErrorType: Error & Decodable {
        self.mappedData(
            urlRequest: urlRequest,
            mapper: mapper,
            completionHandlerQueue: completionHandlerQueue,
            completionHandlers: completionHandlers,
            progressObserver: nil
        )
    }
    
    public func mappedData<ResponseType, ErrorType>(
        urlRequest: URLRequest,
        mapper: MapperProtocol,
        completionHandlerQueue: DispatchQueue,
        completionHandlers: MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType>,
        progressObserver: NetworkOperationProgressObservationProtocol?
    ) where ResponseType: Decodable & Sendable, ErrorType: Error & Decodable {
        let joinedNetworkOperation = self.synchronizationQueue.sync { () -> RawNetworkOperation? in
            if
                let mappedNetworkOperation = self.operations[OperationKey(urlRequest: urlRequest)] as? MappedNetworkOperation<ResponseType, ErrorType>,
                mappedNetworkOperation.mergeCompletionHandlers(
                    contentsOf: [completionHandlerQueue: [completionHandlers]],
                    mapper: mapper
                )
            {
                return mappedNetworkOperation
            }
            let mappedNetworkOperation = MappedNetworkOperation(
                urlRequest: urlRequest,
                urlSession: self.urlSession,
                progressObserver: progressObserver,
                mapper: mapper,
                mappedDataCompletionHandlersHashTable: [completionHandlerQueue: [completionHandlers]]
            )
            self.startTrackingAndPerform(
                operation: mappedNetworkOperation,
                forKey: urlRequest
            )
            return nil
        }
        joinedNetworkOperation?.addProgressObserver(progressObserver)
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
        let joinedNetworkOperation = self.synchronizationQueue.sync { () -> RawNetworkOperation? in
            if
                let rawNetworkOperation = self.operations[OperationKey(urlRequest: urlRequest)],
                rawNetworkOperation.mergeCompletionHandlers(contentsOf: [completionHandlerQueue: [completionHandler]])
            {
                return rawNetworkOperation
            }
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
            return nil
        }
        joinedNetworkOperation?.addProgressObserver(progressObserver)
    }
    
    public func cancelAnyTasksIfNeeded(at urlRequest: URLRequest) {
        let cancelledOperations = self.synchronizationQueue.sync { () -> [RawNetworkOperation] in
            let operationKey = OperationKey(urlRequest: urlRequest)
            let displacedOperations = self._displacedOperations.mutate { (displacedOperations) in
                displacedOperations.removeValue(forKey: operationKey)
            }
            let operation = self._operations.mutate { (operations) in
                operations.removeValue(forKey: operationKey)
            }
            return (displacedOperations ?? []) + [operation].compactMap { $0 }
        }
        cancelledOperations.forEach { (cancelledOperation) in
            cancelledOperation.cancel()
        }
    }
}

// MARK: Sendable
extension NetworkManager: @unchecked Sendable { /* EMPTY */ }
