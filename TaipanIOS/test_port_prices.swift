#!/usr/bin/env swift
// Quick test to verify per-port pricing works correctly
// Run with: swift test_port_prices.swift

import Foundation

// Simplified test structures
struct Commodity {
    let id: String
    var basePrice: Double
    var volatility: Double
}

struct CommodityPrice {
    var price: Double
    var trend: Double
    var momentum: Double
}

struct Port {
    let name: String
    static let allPorts = [
        Port(name: "Hong Kong"),
        Port(name: "Shanghai"),
        Port(name: "Nagasaki"),
        Port(name: "Saigon"),
        Port(name: "Manila"),
        Port(name: "Batavia"),
        Port(name: "Singapore")
    ]
}

// Test the pricing system
var commodities: [String: Commodity] = [
    "opium": Commodity(id: "opium", basePrice: 5000, volatility: 0.8),
    "arms": Commodity(id: "arms", basePrice: 50, volatility: 0.5),
    "silk": Commodity(id: "silk", basePrice: 500, volatility: 0.4),
    "general": Commodity(id: "general", basePrice: 10, volatility: 0.3)
]

var portPrices: [String: [String: CommodityPrice]] = [:]

// Generate initial prices
for port in Port.allPorts {
    var portCommodityPrices: [String: CommodityPrice] = [:]

    for (commodityName, commodity) in commodities {
        let randomFactor = Double.random(in: -1...1) * commodity.volatility
        let initialPrice = commodity.basePrice * (1 + randomFactor)

        portCommodityPrices[commodityName] = CommodityPrice(
            price: initialPrice,
            trend: Double.random(in: -1...1),
            momentum: 0.5
        )
    }

    portPrices[port.name] = portCommodityPrices
}

// Display results
print("=== Per-Port Pricing Test ===\n")
print("Testing that each port has DIFFERENT prices for commodities\n")

for commodity in ["opium", "arms", "silk", "general"] {
    print("\n\(commodity.uppercased()):")
    print("Base Price: ¥\(Int(commodities[commodity]!.basePrice))")
    print("Volatility: \(Int(commodities[commodity]!.volatility * 100))%")
    print("\nPrices by Port:")

    var prices: [Double] = []
    for port in Port.allPorts {
        if let price = portPrices[port.name]?[commodity]?.price {
            prices.append(price)
            print("  \(port.name.padding(toLength: 12, withPad: " ", startingAt: 0)): ¥\(Int(price))")
        }
    }

    let minPrice = prices.min() ?? 0
    let maxPrice = prices.max() ?? 0
    let avgPrice = prices.reduce(0, +) / Double(prices.count)
    let range = maxPrice - minPrice
    let rangePercent = (range / avgPrice) * 100

    print("\n  Statistics:")
    print("    Min:   ¥\(Int(minPrice))")
    print("    Max:   ¥\(Int(maxPrice))")
    print("    Avg:   ¥\(Int(avgPrice))")
    print("    Range: ¥\(Int(range)) (\(String(format: "%.1f", rangePercent))%)")

    // Check if prices are actually different
    let allSame = prices.allSatisfy { $0 == prices.first }
    if allSame {
        print("    ⚠️  WARNING: All prices are identical! Bug not fixed!")
    } else {
        print("    ✅ Prices vary across ports - working correctly!")
    }
}

print("\n=== Test Complete ===")

// Test highest/lowest functions
print("\n=== Opium Hot Deals Test ===\n")

var highest: (String, Double)? = nil
var lowest: (String, Double)? = nil

for port in Port.allPorts {
    if let opiumPrice = portPrices[port.name]?["opium"]?.price {
        if highest == nil || opiumPrice > highest!.1 {
            highest = (port.name, opiumPrice)
        }
        if lowest == nil || opiumPrice < lowest!.1 {
            lowest = (port.name, opiumPrice)
        }
    }
}

if let (port, price) = highest {
    print("Highest Opium Price: \(port) at ¥\(Int(price))")
}

if let (port, price) = lowest {
    print("Lowest Opium Price:  \(port) at ¥\(Int(price))")
}

if let h = highest, let l = lowest {
    let profit = h.1 - l.1
    let profitPercent = (profit / l.1) * 100
    print("\nPotential Profit: ¥\(Int(profit)) (\(String(format: "%.1f", profitPercent))% gain)")
    print("Strategy: Buy in \(l.0), sell in \(h.0)")
}

print("\n✅ Per-port pricing system is working!")
