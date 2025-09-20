This Swift package contains the generated Swift code for the connector `example`.

You can use this package by adding it as a local Swift package dependency in your project.

# Accessing the connector

Add the necessary imports

```
import FirebaseDataConnect
import DataConnectGenerated

```

The connector can be accessed using the following code:

```
let connector = DataConnect.exampleConnector

```


## Connecting to the local Emulator
By default, the connector will connect to the production service.

To connect to the emulator, you can use the following code, which can be called from the `init` function of your SwiftUI app

```
connector.useEmulator()
```

# Queries

# Mutations
