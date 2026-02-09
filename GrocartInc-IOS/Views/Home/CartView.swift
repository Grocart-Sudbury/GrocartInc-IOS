//
//  CartView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

//
//  CartView.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-08.
//

import SwiftUI

struct CartView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.grocartBackground.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "cart")
                        .font(.system(size: 56))
                        .foregroundColor(.grocartSecondary.opacity(0.4))
                    
                    Text("Your cart is empty")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.grocartPrimary)
                    
                    Text("Browse our categories and add\nsome items to get started")
                        .font(.system(size: 15))
                        .foregroundColor(.grocartSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                    
                    Button(action: {}) {
                        Text("Start Shopping")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.grocartGreen)
                            .cornerRadius(12)
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                }
            }
            .navigationTitle("Cart")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    CartView()
}
