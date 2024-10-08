//
//  Login.swift
//  Ryu
//
//  Created by Francesco on 08/08/24.
//

import UIKit

class AniListLogin {
    static let clientID = "19551"
    static let redirectURI = "ryu://anilist"
    
    static let authorizationEndpoint = "https://anilist.co/api/v2/oauth/authorize"
    
    static func authenticate() {
        let urlString = "\(authorizationEndpoint)?client_id=\(clientID)&redirect_uri=\(redirectURI)&response_type=code"
        print(urlString)
        guard let url = URL(string: urlString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    print("Safari opened successfully")
                } else {
                    print("Failed to open Safari")
                }
            }
        } else {
            print("Cannot open URL")
        }
    }
    
    static func handleRedirect(url: URL) {
        print("Redirect URL: \(url)")
        
        guard let code = url.queryParameters?["code"] else {
            print("Failed to extract authorization code")
            return
        }
        
        print("Authorization code received: \(code)")
        AniListToken.exchangeAuthorizationCodeForToken(code: code) { success in
            if success {
                print("Token exchange successful")
            } else {
                print("Token exchange failed")
            }
        }
    }
}
