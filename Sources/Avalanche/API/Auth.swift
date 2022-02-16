//
//  Auth.swift
//  
//
//  Created by Daniel Leping on 27/12/2020.
//

import Foundation
import Serializable
#if !COCOAPODS
import RPC
#endif

public class AvalancheAuthApi: AvalancheApi {
    public let networkID: NetworkID
    public let hrp: String
    
    private let service: Client

    public required init(avalanche: AvalancheCore,
                         networkID: NetworkID,
                         hrp: String)
    {
        self.networkID = networkID
        self.hrp = hrp
        
        self.service = avalanche.connectionProvider.rpc(api: .auth)
    }
    
    public func newToken(password: String,
                         endpoints: [String],
                         cb: @escaping ApiCallback<String>)
    {
        struct NewTokenParams: Encodable {
            let password: String
            let endpoints: [String]
        }
        struct NewTokenResponse: Decodable {
            let token: String
        }
        service.call(
            method: "auth.newToken",
            params: NewTokenParams(password: password, endpoints: endpoints),
            NewTokenResponse.self,
            SerializableValue.self
        ) { response in
            cb(response.map{ $0.token }.mapError(AvalancheApiError.init))
        }
    }
    
    public func revokeToken(password: String,
                            token: String,
                            cb: @escaping ApiCallback<Void>)
    {
        struct RevokeTokenParams: Encodable {
            let password: String
            let token: String
        }
        service.call(
            method: "auth.revokeToken",
            params: RevokeTokenParams(password: password, token: token),
            SuccessResponse.self,
            SerializableValue.self
        ) { response in
            cb(response
                .mapError(AvalancheApiError.init)
                .flatMap { $0.toResult() })
        }
    }
    
    public func changePassword(password: String,
                               newPassword: String,
                               cb: @escaping ApiCallback<Void>)
    {
        struct ChangePasswordParams: Encodable {
            let oldPassword: String
            let newPassword: String
        }
        service.call(
            method: "auth.changePassword",
            params: ChangePasswordParams(
                oldPassword: password,
                newPassword: newPassword
            ),
            SuccessResponse.self,
            SerializableValue.self
        ) { response in
            cb(response
                .mapError(AvalancheApiError.init)
                .flatMap { $0.toResult() })
        }
    }
}

extension AvalancheCore {
    public var auth: AvalancheAuthApi {
        try! self.getAPI()
    }
}
