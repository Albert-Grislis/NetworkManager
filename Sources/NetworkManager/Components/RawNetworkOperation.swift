//
//  RawNetworkOperation.swift
//
//
//  Created by Albert Grislis on 13.02.2021.
//

import Foundation
import Utils

class RawNetworkOperation: AsynchronousOperation, @unchecked Sendable {
    
    // MARK: Internal properties
    let urlRequest: URLRequest
    
    // MARK: Private properties
    private let urlSession: URLSession
    private let taskStateLock = NSLock()
    private var _urlSessionTask: URLSessionTask?
    private weak var _urlSessionTaskProgressObserver: NetworkOperationProgressObservationProtocol?
    private var urlSessionTask: URLSessionTask? {
        get {
            defer {
                self.taskStateLock.unlock()
            }
            self.taskStateLock.lock()
            return self._urlSessionTask
        }
        set {
            defer {
                self.taskStateLock.unlock()
            }
            self.taskStateLock.lock()
            self._urlSessionTask = newValue
        }
    }
    private var urlSessionTaskProgressObserver: NetworkOperationProgressObservationProtocol? {
        defer {
            self.taskStateLock.unlock()
        }
        self.taskStateLock.lock()
        return self._urlSessionTaskProgressObserver
    }
    @UnfairLock private var completionHandlersHashTable: [DispatchQueue: [RawNetworkRequestCompletionHandler]]
    private let completionStateLock = NSLock()
    private var completionIsFinalized = false
    
    // MARK: Initializers & Deinitializers
    init(
        urlRequest: URLRequest,
        urlSession: URLSession,
        progressObserver: NetworkOperationProgressObservationProtocol?,
        completionHandlersHashTable: [DispatchQueue: [RawNetworkRequestCompletionHandler]]?
    ) {
        self.urlRequest = urlRequest
        self.urlSession = urlSession
        self._urlSessionTaskProgressObserver = progressObserver
        self.completionHandlersHashTable = completionHandlersHashTable ?? [:]
        super.init()
    }
    
    deinit {
        self.urlSessionTaskProgressObserver?.invalidateNetworkOperationProgressObservation()
    }
    
    // MARK: Internal methods
    override func main() {
        guard !self.isCancelled else {
            self.finish()
            return
        }
        let urlSessionTask = self.urlSession.dataTask(with: self.urlRequest) { [weak self] (data, _, error) in
            defer {
                self?.finish()
            }
            if let error = error {
                self?.complete(result: .failure(error))
            } else if let data = data {
                self?.complete(result: .success(data))
            } else {
                self?.complete(result: .failure(URLError(.badServerResponse)))
            }
        }
        self.urlSessionTask = urlSessionTask
        guard !self.isCancelled else {
            urlSessionTask.cancel()
            self.finish()
            return
        }
        if let urlSessionTaskProgressObserver = self.urlSessionTaskProgressObserver { // urlSessionTaskProgressObserver exists
            urlSessionTaskProgressObserver.observe(progress: urlSessionTask.progress)
        }
        urlSessionTask.resume()
    }
    
    override func cancel() {
        let shouldDeliverCancellation = self.finalizeCompletionIfNeeded()
        super.cancel()
        self.urlSessionTask?.cancel()
        self.urlSessionTaskProgressObserver?.invalidateNetworkOperationProgressObservation()
        if shouldDeliverCancellation {
            self.deliverCancellation()
        }
    }
    
    @discardableResult func mergeCompletionHandlers(
        contentsOf sequence: [DispatchQueue: [RawNetworkRequestCompletionHandler]]
    ) -> Bool {
        guard !self.isCancelled else {
            return false
        }
        return self.performIfCompletionIsNotFinalized {
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
        guard !self.isCancelled else { return }
        guard self.finalizeCompletionIfNeeded() else { return }
        self.deliverRawCompletionHandlers(result: result)
    }
    
    func deliverRawCompletionHandlers(result: Result<Data, Error>) {
        self.completionHandlersHashTable.forEach { (queue, completionHandlers) in
            queue.sync {
                completionHandlers.forEach { (completionHandler) in
                    completionHandler(result)
                }
            }
        }
    }
    
    func deliverCancellation() {
        self.completionHandlersHashTable.forEach { (queue, completionHandlers) in
            queue.async {
                completionHandlers.forEach { (completionHandler) in
                    completionHandler(.failure(URLError(.cancelled)))
                }
            }
        }
    }
    
    func finalizeCompletionIfNeeded() -> Bool {
        defer {
            self.completionStateLock.unlock()
        }
        self.completionStateLock.lock()
        guard !self.completionIsFinalized else {
            return false
        }
        self.completionIsFinalized = true
        return true
    }
    
    func performIfCompletionIsNotFinalized(_ mutation: () -> Void) -> Bool {
        defer {
            self.completionStateLock.unlock()
        }
        self.completionStateLock.lock()
        guard !self.completionIsFinalized else {
            return false
        }
        mutation()
        return true
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
