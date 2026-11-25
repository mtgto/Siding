import os

nonisolated enum Log {
    static let network = Logger(subsystem: "net.mtgto.Siding", category: "network")
    static let store = Logger(subsystem: "net.mtgto.Siding", category: "store")
}
