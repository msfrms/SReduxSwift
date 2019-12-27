//
// Created by Radaev Mikhail on 17.02.17.
// Copyright (c) 2017 msfrms. All rights reserved.
//

import Foundation
import SUtils

public protocol Action {}

public protocol Dispatcher {
    func dispatch(action: Action)
}

public typealias Reducer<State> = (State, Action) -> State

public typealias Middleware<State> = (State, Action, Dispatcher) -> Void

extension CommandWith: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self)
    }

    public static func == (lhs: CommandWith<T>, rhs: CommandWith<T>) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

public final class Store<State>: Dispatcher {

    public private(set) var state: State
    private let reducer: Reducer<State>
    private let queue: DispatchQueue
    private var commands: Set<CommandWith<State>> = []
    private let middleware: Middleware<State>

    public init(queue: DispatchQueue,
                initialState: State,
                reducer: @escaping Reducer<State>,
                middleware: @escaping Middleware<State> = { _, _, _ in }) {
        self.reducer = reducer
        self.state = initialState
        self.queue = queue
        self.middleware = middleware
    }

    public convenience init(initialState: State,
                            reducer: @escaping Reducer<State>,
                            middleware: @escaping Middleware<State> = { _, _, _ in }) {
        self.init(queue: DispatchQueue(label: "private store queue"),
                  initialState: initialState,
                  reducer: reducer,
                  middleware: middleware)
    }

    @discardableResult
    public func subscribe(command: CommandWith<State>) -> Command {
        queue.async {
            self.commands.insert(command)
            command.execute(value: self.state)
        }
        return Command(id: "stop observing for \(command)") {
            self.commands.remove(command)
        }.observe(queue: self.queue)
    }

    public func setState(_ state: State) {
        self.state = state
        commands.forEach { $0.execute(value: state) }
    }

    public func dispatch(action: Action) {
        queue.async {
            let newState = self.reducer(self.state, action)
            self.state = newState
            self.commands.forEach { $0.execute(value: newState) }
            self.middleware(newState, action, self)
        }
    }
}
