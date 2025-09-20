
import Foundation

import FirebaseCore
import FirebaseDataConnect








public extension DataConnect {

  static let exampleConnector: ExampleConnector = {
    let dc = DataConnect.dataConnect(connectorConfig: ExampleConnector.connectorConfig, callerSDKType: .generated)
    return ExampleConnector(dataConnect: dc)
  }()

}

public class ExampleConnector {

  let dataConnect: DataConnect

  public static let connectorConfig = ConnectorConfig(serviceId: "bumpin", location: "us-central1", connector: "example")

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect

    // init operations 
    
  }

  public func useEmulator(host: String = DataConnect.EmulatorDefaults.host, port: Int = DataConnect.EmulatorDefaults.port) {
    self.dataConnect.useEmulator(host: host, port: port)
  }

  // MARK: Operations


}
