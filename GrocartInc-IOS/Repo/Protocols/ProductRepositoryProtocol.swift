//
//  ProductRepositoryProtocol.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-12.
//

import Foundation

protocol ProductRepositoryProtocol: Sendable {
    func fetchCategories(forceRefresh: Bool) async throws -> [Category]
}
