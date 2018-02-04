//
//  SyncBump.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 11.11.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//

struct SyncBump: Decodable {
    let bumps: [Bump]
    let success: Int
}

struct bumpForServerResponse: Decodable {
    let success: Int
}
