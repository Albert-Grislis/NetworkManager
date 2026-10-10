//
//  Recorder.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation

final class Recorder<Value> where Value: Sendable {

    // MARK: Private types
    private typealias Waiter = (
        id: UUID,
        count: Int,
        continuation: CheckedContinuation<[Value], Never>
    )

    // MARK: Internal properties
    var values: [Value] {
        return self.lock.withLock {
            self.recordedValues
        }
    }

    // MARK: Private properties
    private let lock: NSLock
    private var recordedValues: [Value]
    private var waiters: [Waiter]

    // MARK: initializers & deinitializers
    init() {
        self.lock = NSLock()
        self.recordedValues = []
        self.waiters = []
    }

    // MARK: Internal methods
    @discardableResult func record(_ value: Value) -> Int {
        let (index, recordedValues, satisfiedWaiters) = self.lock.withLock { () -> (Int, [Value], [Waiter]) in
            self.recordedValues.append(value)
            let recordedCount = self.recordedValues.count
            let satisfiedWaiters = self.waiters.filter { (waiter) in
                waiter.count <= recordedCount
            }
            self.waiters.removeAll { (waiter) in
                waiter.count <= recordedCount
            }
            return (recordedCount - 1, self.recordedValues, satisfiedWaiters)
        }
        satisfiedWaiters.forEach { (waiter) in
            waiter.continuation.resume(returning: Array(recordedValues.prefix(waiter.count)))
        }
        return index
    }

    @discardableResult func values(count: Int) async -> [Value] {
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation) in
                let recordedValues = self.lock.withLock { () -> [Value]? in
                    guard self.recordedValues.count >= count || Task.isCancelled else {
                        self.waiters.append(
                            (
                                id: id,
                                count: count,
                                continuation: continuation
                            )
                        )
                        return nil
                    }
                    return Array(self.recordedValues.prefix(count))
                }
                if let recordedValues {
                    continuation.resume(returning: recordedValues)
                }
            }
        } onCancel: {
            let (waiter, recordedValues) = self.lock.withLock { () -> (Waiter?, [Value]) in
                guard let index = self.waiters.firstIndex(where: { (waiter) in waiter.id == id }) else { return (nil, self.recordedValues) }
                return (self.waiters.remove(at: index), self.recordedValues)
            }
            waiter?.continuation.resume(returning: recordedValues)
        }
    }

    func recordingHandler<Input>() -> @Sendable (Input) -> Void where Input: Sendable, Value == Delivery<Input> {
        return { [weak self] (input) in
            guard let self else { return }
            self.record(
                Delivery(
                    value: input,
                    queueLabel: DispatchQueue.currentLabel
                )
            )
        }
    }

    func namingHandler<Input>(_ name: String) -> @Sendable (Input) -> Void where Value == Delivery<String> {
        return { [weak self] _ in
            guard let self else { return }
            self.record(
                Delivery(
                    value: name,
                    queueLabel: DispatchQueue.currentLabel
                )
            )
        }
    }
}

// MARK: Sendable
extension Recorder: @unchecked Sendable { /* EMPTY */ }
