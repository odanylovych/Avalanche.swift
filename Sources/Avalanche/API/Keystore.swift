//
//  Keystore.swift
//  
//
//  Created by Daniel Leping on 27/12/2020.
//

import Foundation
import Serializable
#if !COCOAPODS
import RPC
#endif

public class AvalancheKeystoreApi: AvalancheApi {
    public let networkID: NetworkID
    private let service: Client

    public required init(avalanche: AvalancheCore, networkID: NetworkID) {
        self.networkID = networkID
        self.service = avalanche.connectionProvider.rpc(api: .keystore)
    }
    
    private struct CredentialsParams: Encodable {
        let username: String
        let password: String
    }
    
    public func createUser(username: String,
                           password: String,
                           cb: @escaping ApiCallback<Void>)
    {
        service.call(
            method: "keystore.createUser",
            params: CredentialsParams(username: username, password: password),
            SuccessResponse.self,
            SerializableValue.self
        ) { response in
            cb(response.mapError(AvalancheApiError.init).flatMap { $0.toResult() })
        }
    }
    
    public func deleteUser(username: String,
                           password: String,
                           cb: @escaping ApiCallback<Void>)
    {
        service.call(
            method: "keystore.deleteUser",
            params: CredentialsParams(username: username, password: password),
            SuccessResponse.self,
            SerializableValue.self
        ) { response in
            cb(response.mapError(AvalancheApiError.init).flatMap { $0.toResult() })
        }
    }
    
    public struct ExportUserResponse: Decodable {
        let user: String
        let encoding: ApiDataEncoding
    }
    
    public func exportUser(username: String,
                           password: String,
                           encoding: ApiDataEncoding? = nil,
                           cb: @escaping ApiCallback<ExportUserResponse>)
    {
        struct ExportUserParams: Encodable {
            let username: String
            let password: String
            let encoding: ApiDataEncoding?
        }
        service.call(
            method: "keystore.exportUser",
            params: ExportUserParams(username: username,
                                     password: password,
                                     encoding: encoding),
            ExportUserResponse.self,
            SerializableValue.self
        ) {
            cb($0.mapError(AvalancheApiError.init))
        }
    }
    
    public func importUser(username: String,
                           password: String,
                           user: String,
                           encoding: ApiDataEncoding? = nil,
                           cb: @escaping ApiCallback<Void>) {
        struct ImportUserParams: Encodable {
            let username: String
            let password: String
            let user: String
            let encoding: ApiDataEncoding?
        }
        service.call(
            method: "keystore.importUser",
            params: ImportUserParams(username: username,
                                     password: password,
                                     user: user,
                                     encoding: encoding),
            SuccessResponse.self,
            SerializableValue.self
        ) { response in
            cb(response.mapError(AvalancheApiError.init).flatMap { $0.toResult() })
        }
    }
    
    public func listUsers(cb: @escaping ApiCallback<[String]>) {
        struct Response: Decodable {
            let users: [String]
        }
        service.call(
            method: "keystore.listUsers",
            params: Nil.nil,
            Response.self,
            SerializableValue.self
        ) { response in
            cb(response.mapError(AvalancheApiError.init).map{ $0.users })
        }
    }
}

extension AvalancheCore {
    public var keystore: AvalancheKeystoreApi {
        try! self.getAPI()
    }
}
