//
//  StubServer+Registry.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 10.10.2026.
//

import Foundation

extension StubServer {
    final class Registry {

        // MARK: Private properties
        private let lock: NSLock
        private let servers: NSMapTable<NSString, StubServer>

        // MARK: initializers & deinitializers
        init() {
            self.lock = NSLock()
            self.servers = NSMapTable<NSString, StubServer>.strongToWeakObjects()
        }

        // MARK: Internal methods
        func register(_ server: StubServer, forHost host: String) {
            self.lock.withLock {
                self.servers.setObject(server, forKey: host as NSString)
            }
        }

        func server(forHost host: String) -> StubServer? {
            return self.lock.withLock {
                self.servers.object(forKey: host as NSString)
            }
        }
    }
}

// MARK: Sendable
extension StubServer.Registry: @unchecked Sendable { /* EMPTY */ }
