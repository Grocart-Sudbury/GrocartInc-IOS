//
//  CacheManager.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-12.
//

//
//  CacheManager.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-12.
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.grocartinc.ios", category: "CacheManager")

final class CacheManager: @unchecked Sendable {
    
    static let shared = CacheManager()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        let documentsDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        cacheDirectory = documentsDir.appendingPathComponent("grocart_cache", isDirectory: true)
        
        // Create cache directory if needed
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Save
    func save<T: Encodable>(_ data: T, forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        let metaURL = cacheDirectory.appendingPathComponent("\(key)_meta.json")
        
        do {
            let jsonData = try JSONEncoder().encode(data)
            try jsonData.write(to: fileURL)
            
            // Save timestamp
            let meta = CacheMeta(savedAt: Date())
            let metaData = try JSONEncoder().encode(meta)
            try metaData.write(to: metaURL)
            
            logger.info("Cache saved: \(key) (\(jsonData.count) bytes)")
        } catch {
            logger.error("Cache save failed for \(key): \(error)")
        }
    }
    
    // MARK: - Load
    func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(T.self, from: data)
            logger.info("Cache loaded: \(key)")
            return decoded
        } catch {
            logger.error("Cache load failed for \(key): \(error)")
            return nil
        }
    }
    
    // MARK: - Check if cache is still valid
    func isValid(forKey key: String, ttl: TimeInterval) -> Bool {
        let metaURL = cacheDirectory.appendingPathComponent("\(key)_meta.json")
        
        guard let metaData = try? Data(contentsOf: metaURL),
              let meta = try? JSONDecoder().decode(CacheMeta.self, from: metaData)
        else { return false }
        
        let age = Date().timeIntervalSince(meta.savedAt)
        let valid = age < ttl
        logger.debug("Cache '\(key)' age: \(Int(age))s, TTL: \(Int(ttl))s, valid: \(valid)")
        return valid
    }
    
    // MARK: - Clear
    func clear(forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        let metaURL = cacheDirectory.appendingPathComponent("\(key)_meta.json")
        try? fileManager.removeItem(at: fileURL)
        try? fileManager.removeItem(at: metaURL)
        logger.info("Cache cleared: \(key)")
    }
    
    func clearAll() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        logger.info("All cache cleared")
    }
}

// MARK: - Cache Metadata
private struct CacheMeta: Codable {
    let savedAt: Date
}
