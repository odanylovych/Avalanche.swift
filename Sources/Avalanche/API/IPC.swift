//
//  IPC.swift
//  
//
//  Created by Daniel Leping on 27/12/2020.
//

import Foundation
import Serializable
#if !COCOAPODS
import RPC
#endif

public struct AvalancheIPCApiInfo: AvalancheApiInfo {
    public let connection: ApiConnection = .ipc(path: "/ext/ipcs")
}

public class AvalancheIPCApi: AvalancheApi {
    public typealias Info = AvalancheIPCApiInfo

    public let networkID: NetworkID
    public let hrp: String
    public let info: Info
    
    private let service: Client

    public required init(avalanche: AvalancheCore,
                         networkID: NetworkID,
                         hrp: String,
                         info: AvalancheIPCApiInfo)
    {
        self.info = info
        self.hrp = hrp
        self.networkID = networkID
        
        self.service = avalanche.connectionProvider.rpc(api: info.connection)
    }
    
    public struct PublishBlockchainResponse: Decodable {
        let consensusURL: String
        let decisionsURL: String
    }
    
    private struct IPCRequestParams: Encodable {
        let blockchainID: String
    }
    
    public func publishBlockchain(
        blockchainID: BlockchainID,
        cb: @escaping ApiCallback<PublishBlockchainResponse>
    ) {
        service.call(
            method: "ipcs.publishBlockchain",
            params: IPCRequestParams(blockchainID: blockchainID.cb58()),
            PublishBlockchainResponse.self,
            SerializableValue.self
        ) {
            cb($0.mapError(AvalancheApiError.init))
        }
    }
    
    public func unpublishBlockchain(
        blockchainID: BlockchainID,
        cb: @escaping ApiCallback<Void>
    ) {
        service.call(
            method: "ipcs.unpublishBlockchain",
            params: IPCRequestParams(blockchainID: blockchainID.cb58()),
            SuccessResponse.self,
            SerializableValue.self
        ) { response in
            cb(response.mapError(AvalancheApiError.init).flatMap { $0.toResult() })
        }
    }
}

extension AvalancheCore {
    public var ipc: AvalancheIPCApi {
        try! self.getAPI()
    }
}
