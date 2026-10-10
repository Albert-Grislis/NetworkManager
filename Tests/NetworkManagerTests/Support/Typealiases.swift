//
//  Typealiases.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation

typealias RawDeliveries = Recorder<Delivery<Result<Data, Error>>>
typealias StubResponder = @Sendable (_ index: Int, _ exchange: StubExchange) -> StubReply?
