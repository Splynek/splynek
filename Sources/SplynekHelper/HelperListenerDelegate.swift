import Foundation

/// v1.8.2: NSXPCListener delegate that accepts new connections from
/// the Splynek app + exports the SplynekHelperProtocol service.
///
/// **Trust boundary.**  NSXPCConnection enforces the
/// SMAuthorizedClients requirement string in this bundle's
/// Info.plist before delivering messages — so by the time
/// `listener(_:shouldAcceptNewConnection:)` returns true, we know
/// the peer is a properly-signed Splynek.app whose code-signing
/// identity matches our SMAuthorizedClients string.
final class HelperListenerDelegate: NSObject, NSXPCListenerDelegate {

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        // Export the SplynekHelperProtocol service.  Every method
        // declared on the protocol is callable by the client over
        // this connection.
        newConnection.exportedInterface = NSXPCInterface(
            with: SplynekHelperProtocol.self
        )
        newConnection.exportedObject = HelperService()
        newConnection.resume()
        return true
    }
}
