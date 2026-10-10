//
//  MappedNetworkOperation.swift
//  NetworkManager
//
//  Created by Albert Grislis on 25.12.2021.
//

import Foundation
import Utils

final class MappedNetworkOperation<ResponseType, ErrorType>: RawNetworkOperation
where ResponseType: Decodable & Sendable, ErrorType: Error & Decodable {

    // MARK: Private types
    private typealias MappedDataCompletionHandlersHashTable = [DispatchQueue: [MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType>]]
    private typealias MappedDataCompletionHandlersBatch = (
        mapper: MapperProtocol,
        completionHandlersHashTable: MappedDataCompletionHandlersHashTable
    )
    
    // MARK: Private properties
    @UnfairLock private var mappedDataCompletionHandlersBatches: [MappedDataCompletionHandlersBatch]
    
    // MARK: Initializers & Deinitializers
    init(
        urlRequest: URLRequest,
        urlSession: URLSession,
        progressObserver: NetworkOperationProgressObservationProtocol?,
        mapper: MapperProtocol,
        mappedDataCompletionHandlersHashTable: [DispatchQueue: [MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType>]]?
    ) {
        self.mappedDataCompletionHandlersBatches = [
            (
                mapper: mapper,
                completionHandlersHashTable: mappedDataCompletionHandlersHashTable ?? [:]
            ),
        ]
        super.init(
            urlRequest: urlRequest,
            urlSession: urlSession,
            progressObserver: progressObserver,
            completionHandlersHashTable: [:]
        )
    }
    
    // MARK: Internal methods
    @discardableResult func mergeCompletionHandlers(
        contentsOf sequence: [DispatchQueue: [MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType>]],
        mapper: MapperProtocol
    ) -> Bool {
        guard !self.isCancelled else { return false }
        return self.performIfCompletionIsNotFinalized {
            self._mappedDataCompletionHandlersBatches.mutate { (mappedDataCompletionHandlersBatches) in
                mappedDataCompletionHandlersBatches.append(
                    (
                        mapper: mapper,
                        completionHandlersHashTable: sequence
                    )
                )
            }
        }
    }
    
    override func complete(result: Result<Data, Error>) {
        guard !self.isCancelled else {
            return
        }
        guard self.finalizeCompletionIfNeeded() else {
            return
        }
        self.deliverRawCompletionHandlers(result: result)
        self.mappedDataCompletionHandlersBatches.forEach { (mapper, completionHandlersHashTable) in
            self.complete(
                result: result,
                mapper: mapper,
                completionHandlersHashTable: completionHandlersHashTable
            )
        }
    }

    override func deliverCancellation() {
        super.deliverCancellation()
        let completionHandlersHashTable = self.mappedDataCompletionHandlersBatches.reduce(into: MappedDataCompletionHandlersHashTable()) { (result, mappedDataCompletionHandlersBatch) in
            result.merge(
                mappedDataCompletionHandlersBatch.completionHandlersHashTable,
                uniquingKeysWith: +
            )
        }
        completionHandlersHashTable.forEach { (queue, completionHandlers) in
            queue.async {
                completionHandlers.forEach { (completionHandler) in
                    completionHandler.failure?(.failure(URLError(.cancelled)))
                }
            }
        }
    }

    // MARK: Private methods
    private func complete(
        result: Result<Data, Error>,
        mapper: MapperProtocol,
        completionHandlersHashTable: MappedDataCompletionHandlersHashTable
    ) {
        switch result {
        case let .success(data):
            do {
                let mappedData: ResponseType = try mapper.map(data: data)
                completionHandlersHashTable.forEach { (queue, completionHandlers) in
                    queue.sync {
                        completionHandlers.forEach { (completionHandler) in
                            completionHandler.success(.success(mappedData))
                        }
                    }
                }
            } catch let decodingError as DecodingError {
                do {
                    let mappedError: ErrorType = try mapper.map(data: data)
                    self.complete(
                        failure: mappedError,
                        completionHandlersHashTable: completionHandlersHashTable
                    )
                } catch {
                    self.completeWithAnyError(
                        decodingError,
                        completionHandlersHashTable: completionHandlersHashTable
                    )
                }
            } catch {
                self.completeWithAnyError(
                    error,
                    completionHandlersHashTable: completionHandlersHashTable
                )
            }
        case let .failure(error):
            self.completeWithAnyError(
                error,
                completionHandlersHashTable: completionHandlersHashTable
            )
        }
    }
    
    private func complete(
        failure error: ErrorType,
        completionHandlersHashTable: MappedDataCompletionHandlersHashTable
    ) {
        completionHandlersHashTable.forEach { (queue, completionHandlers) in
            queue.sync {
                completionHandlers.forEach { (completionHandler) in
                    completionHandler.success(.failure(error))
                }
            }
        }
    }
    
    private func completeWithAnyError(
        _ error: Error,
        completionHandlersHashTable: MappedDataCompletionHandlersHashTable
    ) {
        completionHandlersHashTable.forEach { (queue, completionHandlers) in
            queue.sync {
                completionHandlers.forEach { (completionHandler) in
                    completionHandler.failure?(.failure(error))
                }
            }
        }
    }
}

// MARK: Sendable
extension MappedNetworkOperation: @unchecked Sendable { /* EMPTY */ }
