//
//  MappedNetworkOperation.swift
//  
//
//  Created by Albert Grislis on 25.12.2021.
//

import Foundation
import Utils

final class MappedNetworkOperation<ResponseType, ErrorType>: RawNetworkOperation, @unchecked Sendable where ResponseType: Decodable, ErrorType: Error & Decodable {
    
    // MARK: Private properties
    private let mapper: MapperProtocol
    @UnfairLock private var mappedDataCompletionHandlersHashTable: [DispatchQueue: [MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType>]]
    
    // MARK: Initializers & Deinitializers
    init(
        urlRequest: URLRequest,
        urlSession: URLSession,
        progressObserver: NetworkOperationProgressObservationProtocol?,
        mapper: MapperProtocol,
        mappedDataCompletionHandlersHashTable: [DispatchQueue: [MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType>]]?
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
        contentsOf sequence: [DispatchQueue: [MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType>]]
    ) {
        guard !self.isCancelled else { return }
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
                            completionHandler.success(.success(mappedData))
                        }
                    }
                }
            } catch let decodingError as DecodingError {
                do {
                    let mappedError: ErrorType = try self.mapper.map(data: data)
                    self.complete(failure: mappedError)
                } catch {
                    self.completeWithAnyError(decodingError)
                }
            } catch {
                self.completeWithAnyError(error)
            }
        case let .failure(error):
            self.completeWithAnyError(error)
        }
    }
    
    // MARK: Private methods
    private func complete(failure error: ErrorType) {
        self.mappedDataCompletionHandlersHashTable.forEach { (queue, completionHandlers) in
            queue.sync {
                completionHandlers.forEach { (completionHandler) in
                    completionHandler.success(.failure(error))
                }
            }
        }
    }
    
    private func completeWithAnyError(_ error: Error) {
        self.mappedDataCompletionHandlersHashTable.forEach { (queue, completionHandlers) in
            queue.sync {
                completionHandlers.forEach { (completionHandler) in
                    completionHandler.failure?(.failure(error))
                }
            }
        }
    }
    
    private func safeMutateMappedDataCompletionHandlersHashTable(
        completionHandlers: [MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType>],
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
