

//
//  SupabaseService .swift
//  DailyFinance
//
//  Created by Shibbir on 9/3/26.
//


// Services/SupabaseService.swift
import Supabase
import Foundation

class SupabaseService {

    // Shared instance (singleton)
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseKey
        )
    }
}
