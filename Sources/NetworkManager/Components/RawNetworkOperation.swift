//
//  RawNetworkOperation.swift
//
//
//  Created by Albert Grislis on 13.02.2021.
//

import Foundation
import Utils

class RawNetworkOperation: AsynchronousOperation {
    
    // MARK: Internal properties
    let urlRequest: URLRequest
    
    // MARK: Private properties
    private let urlSession: URLSession
    private var urlSessionTask: URLSessionTask?
    private weak var urlSessionTaskProgressObserver: NetworkOperationProgressObservationProtocol?
    @UnfairLock private var completionHandlersHashTable: [DispatchQueue: [RawNetworkRequestCompletionHandler]]
    
    // MARK: Initializers & Deinitializers
    init(
        urlRequest: URLRequest,
        urlSession: URLSession,
        progressObserver: NetworkOperationProgressObservationProtocol?,
        completionHandlersHashTable: [DispatchQueue: [RawNetworkRequestCompletionHandler]]?
    ) {
        self.urlRequest = urlRequest
        self.urlSession = urlSession
        self.urlSessionTaskProgressObserver = progressObserver
        self.completionHandlersHashTable = completionHandlersHashTable ?? [:]
        super.init()
    }
    
    deinit {
        self.urlSessionTaskProgressObserver?.invalidateNetworkOperationProgressObservation()
    }
    
    // MARK: Internal methods
    override func main() {
        guard !self.isCancelled else {
            return
        }
        self.urlSessionTask = self.urlSession.dataTask(with: self.urlRequest) { [weak self] (data, _, error) in
            defer {
                self?.finish()
            }
            if let error = error {
                self?.complete(result: .failure(error))
            } else if let data = data {
                self?.complete(result: .success(data))
            }
        }
        if // urlSessionTaskProgressObserver exists
            let urlSessionTask = self.urlSessionTask,
            let urlSessionTaskProgressObserver = self.urlSessionTaskProgressObserver {
            urlSessionTaskProgressObserver.observe(progress: urlSessionTask.progress)
        }
        self.urlSessionTask?.resume()
    }
    
    override func cancel() {
        super.cancel()
        self.urlSessionTask?.cancel()
        self.urlSessionTaskProgressObserver?.invalidateNetworkOperationProgressObservation()
    }
    
    func mergeCompletionHandlers(
        contentsOf sequence: [DispatchQueue: [RawNetworkRequestCompletionHandler]]
    ) {
        if !self.isCancelled {
            sequence.forEach { (queue, completionHandlers) in
                if var currentCompletionHandlers = self.completionHandlersHashTable[queue] {
                    currentCompletionHandlers.append(contentsOf: completionHandlers)
                    self.safeMutateCompletionHandlersHashTable(
                        completionHandlers: currentCompletionHandlers,
                        forKey: queue
                    )
                } else {
                    self.safeMutateCompletionHandlersHashTable(
                        completionHandlers: completionHandlers,
                        forKey: queue
                    )
                }
            }
        }
    }
    
    func complete(result: Result<Data, Error>) {
        if !self.isCancelled {
            self.completionHandlersHashTable.forEach { (queue, completionHandlers) in
                queue.sync {
                    completionHandlers.forEach { (completionHandler) in
                        completionHandler(result)
                    }
                }
            }
        }
    }
    
    // MARK: Private methods
    private func safeMutateCompletionHandlersHashTable(
        completionHandlers: [RawNetworkRequestCompletionHandler],
        forKey queue: DispatchQueue
    ) {
        self._completionHandlersHashTable.mutate { (completionHandlersHashTable) in
            completionHandlersHashTable.updateValue(
                completionHandlers,
                forKey: queue
            )
        }
    }
}
