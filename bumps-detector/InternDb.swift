//
//  InternDb.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 7.12.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//

import SQLite3
import Foundation

enum SQLiteError: Error {
    case OpenDatabase(message: String)
    case Prepare(message: String)
    case Step(message: String)
    case Bind(message: String)
}

protocol SQLTable {
    static var createStatement: String { get }
}

extension Contact: SQLTable {
    static var createStatement: String {
        return """
        CREATE TABLE Contact(
        Id INT PRIMARY KEY NOT NULL,
        Name CHAR(255)
        );
        """
    }
}

struct Contact {
    let id: Int32
    let name: NSString
}

class SQLiteDatabase {
    fileprivate let dbPointer: OpaquePointer?
    
    fileprivate init(dbPointer: OpaquePointer?) {
        self.dbPointer = dbPointer
    }
    
    deinit {
        sqlite3_close(dbPointer)
    }
    
    static func open(path: String) throws -> SQLiteDatabase {
        var db: OpaquePointer? = nil
        // 1
        if sqlite3_open(path, &db) == SQLITE_OK {
            // 2
            return SQLiteDatabase(dbPointer: db)
        } else {
            // 3
            defer {
                if db != nil {
                    sqlite3_close(db)
                }
            }
            
            if let errorPointer = sqlite3_errmsg(db) {
                let message = String.init(cString: errorPointer)
                throw SQLiteError.OpenDatabase(message: message)
            } else {
                throw SQLiteError.OpenDatabase(message: "No error message provided from sqlite.")
            }
        }
    }
    
//    let db: SQLiteDatabase
//    do {
//    db = try SQLiteDatabase.open(path: part2DbPath)
//    print("Successfully opened connection to database.")
//    } catch SQLiteError.OpenDatabase(let message) {
//    print("Unable to open database. Verify that you created the directory described in the Getting Started section.")
//    }
    
    fileprivate var errorMessage: String {
        if let errorPointer = sqlite3_errmsg(dbPointer) {
            let errorMessage = String(cString: errorPointer)
            return errorMessage
        } else {
            return "No error message provided from sqlite."
        }
    }
}

extension SQLiteDatabase {
    func prepareStatement(sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer? = nil
        guard sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.Prepare(message: errorMessage)
        }
        
        return statement
    }
}
//    do {
//    try db.createTable(table: Contact.self)
//    } catch {
//    print(db.errorMessage)
//    }

extension SQLiteDatabase {
    func createTable(table: SQLTable.Type) throws {
        // 1
        let createTableStatement = try prepareStatement(sql: table.createStatement)
        // 2
        defer {
            sqlite3_finalize(createTableStatement)
        }
        // 3
        guard sqlite3_step(createTableStatement) == SQLITE_DONE else {
            throw SQLiteError.Step(message: errorMessage)
        }
        print("\(table) table created.")
    }
}

//do {
//    try db.insertContact(contact: Contact(id: 1, name: "Ray"))
//} catch {
//    print(db.errorMessage)
//}
extension SQLiteDatabase {
    func insertContact(contact: Contact) throws {
        let insertSql = "INSERT INTO Contact (Id, Name) VALUES (?, ?);"
        let insertStatement = try prepareStatement(sql: insertSql)
        defer {
            sqlite3_finalize(insertStatement)
        }
        
        let name: NSString = contact.name
        guard sqlite3_bind_int(insertStatement, 1, contact.id) == SQLITE_OK  &&
            sqlite3_bind_text(insertStatement, 2, name.utf8String, -1, nil) == SQLITE_OK else {
                throw SQLiteError.Bind(message: errorMessage)
        }
        
        guard sqlite3_step(insertStatement) == SQLITE_DONE else {
            throw SQLiteError.Step(message: errorMessage)
        }
        
        print("Successfully inserted row.")
    }
}

//let first = db.contact(id: 1)
//print("\(first?.id) \(first?.name)")

extension SQLiteDatabase {
    func contact(id: Int32) -> Contact? {
        let querySql = "SELECT * FROM Contact WHERE Id = ?;"
        guard let queryStatement = try? prepareStatement(sql: querySql) else {
            return nil
        }
        
        defer {
            sqlite3_finalize(queryStatement)
        }
        
        guard sqlite3_bind_int(queryStatement, 1, id) == SQLITE_OK else {
            return nil
        }
        
        guard sqlite3_step(queryStatement) == SQLITE_ROW else {
            return nil
        }
        
        let id = sqlite3_column_int(queryStatement, 0)
        
        let queryResultCol1 = sqlite3_column_text(queryStatement, 1)
        let name = String(cString: queryResultCol1!) as NSString
        
        return Contact(id: id, name: name)
    }
}
