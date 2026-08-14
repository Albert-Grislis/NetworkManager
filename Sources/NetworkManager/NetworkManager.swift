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
    @UnfairLock private var operations: [OperationKey: RawNetworkOperation]
    private let operationQueue: OperationQueue
    private let urlSession: URLSession
    private let synchronizationQueue = DispatchQueue(label: "com.networkmanager.synchronization")
    
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
        let operationKey = OperationKey(urlRequest: urlRequest)
        operation.completionBlock = { [weak self, weak operation] in
            self?.synchronizationQueue.async {
                self?._operations.mutate { (operations) in
                    guard
                        let operation = operation,
                        operations[operationKey] === operation
                    else {
                        return
                    }
                    operations.removeValue(forKey: operationKey)
                }
            }
        }
        self._operations.mutate { (operations) in
            operations.updateValue(
                operation,
                forKey: operationKey
            )
        }
        self.operationQueue.addOperation(operation)
    }
}

// MARK: OperationKey
private extension NetworkManager {

    /// Registry key that keeps requests differing only by body apart, since `URLRequest` equality and hashing ignore `httpBody`.
    struct OperationKey: Hashable {

        // MARK: Internal properties
        let urlRequest: URLRequest
        let httpBody: Data?

        // MARK: Initializers & Deinitializers
        init(urlRequest: URLRequest) {
            self.urlRequest = urlRequest
            self.httpBody = urlRequest.httpBody
        }
    }
}

// MARK: NetworkManagerProtocol
extension NetworkManager: NetworkManagerProtocol {    
    public func mappedData<ResponseType, ErrorType>(
        url: URL,
        mapper: MapperProtocol,
        completionHandlerQueue: DispatchQueue,
        completionHandlers: MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType>
    ) where ResponseType: Decodable, ErrorType: Error & Decodable {
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
    ) where ResponseType: Decodable, ErrorType: Error & Decodable {
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
    ) where ResponseType: Decodable, ErrorType: Error & Decodable {
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
    ) where ResponseType: Decodable, ErrorType: Error & Decodable {
        self.synchronizationQueue.sync {
            if
                let mappedNetworkOperation = self.operations[OperationKey(urlRequest: urlRequest)] as? MappedNetworkOperation<ResponseType, ErrorType>,
                mappedNetworkOperation.mergeCompletionHandlers(contentsOf: [completionHandlerQueue: [completionHandlers]]) {
                return
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
        self.synchronizationQueue.sync {
            if
                let rawNetworkOperation = self.operations[OperationKey(urlRequest: urlRequest)],
                rawNetworkOperation.mergeCompletionHandlers(contentsOf: [completionHandlerQueue: [completionHandler]]) {
                return
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
        }
    }
    
    public func cancelAnyTasksIfNeeded(at urlRequest: URLRequest) {
        self.synchronizationQueue.sync {
            self._operations.mutate { (operations) in
                operations.removeValue(forKey: OperationKey(urlRequest: urlRequest))
            }?.cancel()
        }
    }
}
