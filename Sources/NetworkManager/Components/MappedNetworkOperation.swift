//
//  MappedNetworkOperation.swift
//  
//
//  Created by Albert Grislis on 25.12.2021.
//

import Foundation
import Utils

final class MappedNetworkOperation<ResponseType>: RawNetworkOperation where ResponseType: Decodable {
    
    // MARK: Private properties
    private let mapper: MapperProtocol
    @UnfairLock private var mappedDataCompletionHandlersHashTable: [DispatchQueue: [MappedNetworkRequestCompletionHandler<ResponseType>]]
    
    // MARK: Initializers & Deinitializers
    init(
        urlRequest: URLRequest,
        urlSession: URLSession,
        progressObserver: NetworkOperationProgressObservationProtocol?,
        mapper: MapperProtocol,
        mappedDataCompletionHandlersHashTable: [DispatchQueue: [MappedNetworkRequestCompletionHandler<ResponseType>]]?
    ) {
        self.mapper = mapper
        self.mappedDataCompletionHandlersHashTable = mappedDataCompletionHandlersHashTable ?? [:]
        super.init(
            urlRequest: urlRequest,
            urlSession: urlSession,
            progressObserver: progressObserver,
            completionHandlersHashTable: [:]
        )
    }
    
    // MARK: Internal methods
    func mergeCompletionHandlers(
        contentsOf sequence: [DispatchQueue: [MappedNetworkRequestCompletionHandler<ResponseType>]]
    ) {
        if !self.isCancelled {
            sequence.forEach { (queue, completionHandlers) in
                if var currentCompletionHandlers = self.mappedDataCompletionHandlersHashTable[queue] {
                    currentCompletionHandlers.append(contentsOf: completionHandlers)
                    self.safeMutateMappedDataCompletionHandlersHashTable(
                        completionHandlers: currentCompletionHandlers,
                        forKey: queue
                    )
                } else {
                    self.safeMutateMappedDataCompletionHandlersHashTable(
                        completionHandlers: completionHandlers,
                        forKey: queue
                    )
                }
            }
        }
    }
    
    override func complete(result: Result<Data, Error>) {
        guard !self.isCancelled else {
            return
        }
        switch result {
        case let .success(data):
            do {
                let mappedData: ResponseType = try self.mapper.map(data: data)
                self.mappedDataCompletionHandlersHashTable.forEach { (queue, completionHandlers) in
                    queue.sync {
                        completionHandlers.forEach { (completionHandler) in
                            completionHandler(.success(mappedData))
                        }
                    }
                }
            } catch {
                self.complete(failure: error)
            }
        case let .failure(error):
            self.complete(failure: error)
        }
    }
    
    // MARK: Private methods
    private func complete(failure error: Error) {
        self.mappedDataCompletionHandlersHashTable.forEach { (queue, completionHandlers) in
            queue.sync {
                completionHandlers.forEach { (completionHandler) in
                    completionHandler(.failure(error))
                }
            }
        }
    }
    
    // MARK: Private methods
    private func safeMutateMappedDataCompletionHandlersHashTable(
        completionHandlers: [MappedNetworkRequestCompletionHandler<ResponseType>],
        forKey queue: DispatchQueue
    ) {
        self._mappedDataCompletionHandlersHashTable.mutate { (completionHandlersHashTable) in
            completionHandlersHashTable.updateValue(
                completionHandlers,
                forKey: queue
            )
        }
    }
}
