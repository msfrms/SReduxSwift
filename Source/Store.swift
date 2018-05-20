//
// Created by Radaev Mikhail on 17.02.17.
// Copyright (c) 2017 msfrms. All rights reserved.
//

import Foundation
import SUtils

public typealias Reducer<State> = (State, Action) -> State
public typealias SubscriberFilter<State> = (State, State, Action) -> Bool

public protocol Action {}

public protocol Dispatcher {
    func dispatch(action: Action)
}

public struct Pass {
    public static func always<State>(_ oldState: State, _ newState: State, _ action: Action) -> Bool { return true }
    public static func stateHasChanged<State: Equatable>(_ oldState: State, _ newState: State, _ action: Action) -> Bool { return oldState != newState }
}

public final class Store<State>: Dispatcher {

    private class Subscriber: Hashable {

        let command: CommandWith<State>
        let pass: SubscriberFilter<State>

        init(command: CommandWith<State>, filter: @escaping SubscriberFilter<State>) {
            self.command = command
            self.pass = filter
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
        return subscribe(command: command, with: Pass.always)
    }

    @discardableResult
    public func subscribe(command: CommandWith<State>, with filter: @escaping SubscriberFilter<State>) -> Command {
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
            let oldState = self.state
            let newState = self.reducer(oldState, action)
            self.state = newState
            self.subscribers
                    .filter { $0.pass(oldState, newState, action) }
                    .forEach { $0.command.execute(value: newState) }
        }
    }
}
