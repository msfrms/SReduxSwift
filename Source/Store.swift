//
// Created by Radaev Mikhail on 17.02.17.
// Copyright (c) 2017 msfrms. All rights reserved.
//

import Foundation
import SUtils

public typealias Reducer<State> = (State, Action) -> State

public protocol Action {}

public protocol Subscriber {
    associatedtype State
    func subscribe(command: CommandWith<State>) -> Command
}

public protocol Dispatcher {
    func dispatch(action: Action)
}

extension CommandWith: Hashable {

    public var hashValue: Int { return ObjectIdentifier(self).hashValue }

    public static func ==(lhs: CommandWith<T>, rhs: CommandWith<T>) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

public final class Store<State>: Dispatcher, Subscriber {

    public private(set) var state: State
    private let reducer: Reducer<State>
    private let queue: DispatchQueue
    private var subscribers: Set<CommandWith<State>> = []

    public init(queue: DispatchQueue, initialState: State, reducer: @escaping Reducer<State>) {
        self.reducer = reducer
        self.state = initialState
        self.queue = queue
    }

    public convenience init(initialState: State, reducer: @escaping Reducer<State>) {
        self.init(queue: DispatchQueue(label: "private store queue"), initialState: initialState, reducer: reducer)
    }

    @discardableResult
    public func subscribe(command: CommandWith<State>) -> Command {
        self.queue.async {
            self.subscribers.insert(command)
            command.execute(value: self.state)
        }
        return Command(id: "stop observing for \(command)") { [weak command] in
            command.foreach { self.subscribers.remove($0) }
        }
    }

    public func dispatch(action: Action) {
        self.queue.async {
            self.state = self.reducer(self.state, action)
            self.subscribers.forEach { $0.execute(value: self.state) }
        }
    }
}

