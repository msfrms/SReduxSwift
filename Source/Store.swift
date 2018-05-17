//
// Created by Radaev Mikhail on 17.02.17.
// Copyright (c) 2017 msfrms. All rights reserved.
//

import Foundation
import SUtils

public typealias Reducer<State> = (State, Action) -> State

public protocol Action {}

public protocol Dispatcher {
    func dispatch(action: Action)
}

public protocol Filter {
    func filter(action: Action) -> Bool
}

public final class Store<State>: Dispatcher {

    class Pass: Filter {
        func filter(action: Action) -> Bool { return true }
    }

    class Subscriber: Hashable {

        let command: CommandWith<State>
        let filter: Filter

        init(command: CommandWith<State>, filter: Filter) {
            self.command = command
            self.filter = filter
        }

        var hashValue: Int { return ObjectIdentifier(self).hashValue }

       static func == (lhs: Subscriber, rhs: Subscriber) -> Bool {
           return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
        }
    }

    public private(set) var state: State
    private let reducer: Reducer<State>
    private let queue: DispatchQueue
    private var subscribers: Set<Subscriber> = []

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
        return subscribe(command: command, for: Pass())
    }

    @discardableResult
    public func subscribe(command: CommandWith<State>, for filter: Filter) -> Command {
        let subscriber = Subscriber(command: command, filter: filter)
        self.queue.async {
            self.subscribers.insert(subscriber)
            command.execute(value: self.state)
        }
        return Command(id: "stop observing for \(subscriber)") { [weak subscriber] in
            subscriber.foreach { self.subscribers.remove($0) }
        }.observe(queue: self.queue)
    }

    public func dispatch(action: Action) {
        self.queue.async {
            self.state = self.reducer(self.state, action)
            self.subscribers
                .filter { $0.filter.filter(action: action) }
                .forEach { $0.command.execute(value: self.state) }
        }
    }
}

