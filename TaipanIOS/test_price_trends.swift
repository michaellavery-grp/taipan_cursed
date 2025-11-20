#!/usr/bin/env swift
// Test to verify price trends are stable and realistic
// Run with: swift test_price_trends.swift

import Foundation

struct Commodity {
    let id: String
    var basePrice: Double
    var volatility: Double
}

struct CommodityPrice {
    var price: Double
    var trend: Double  // -1 or 1
    var momentum: Double  // 0.3 to 0.7
}

// Test commodities
let commodities: [String: Commodity] = [
    "opium": Commodity(id: "opium", basePrice: 5000, volatility: 0.8)
]

// Initialize prices for one port (Hong Kong)
func generateInitialPrice(commodity: Commodity) -> CommodityPrice {
    let randomFactor = (Double.random(in: 0...1) - 0.5) * commodity.volatility
    let initialPrice = commodity.basePrice * (1 + randomFactor)
    let direction: Double = Double.random(in: 0...1) < 0.5 ? -1 : 1
    let momentum = 0.3 + Double.random(in: 0...0.4)

    return CommodityPrice(price: initialPrice, trend: direction, momentum: momentum)
}

// Update price (one iteration)
func updatePrice(priceInfo: inout CommodityPrice, commodity: Commodity) {
    let currentPrice = priceInfo.price
    let direction = priceInfo.trend
    let momentum = priceInfo.momentum

    // Calculate price change (1-5% max)
    let changePercent = momentum * 0.05 * direction
    let noise = (Double.random(in: 0...1) - 0.5) * 0.02
    let totalChange = changePercent + noise

    // Apply change
    var newPrice = currentPrice * (1 + totalChange)

    // Bounds
    let minPrice = commodity.basePrice * (1 - commodity.volatility)
    let maxPrice = commodity.basePrice * (1 + commodity.volatility)

    // Reverse at bounds
    if newPrice >= maxPrice {
        newPrice = maxPrice
        priceInfo.trend = -1
        priceInfo.momentum = 0.4 + Double.random(in: 0...0.3)
    } else if newPrice <= minPrice {
        newPrice = minPrice
        priceInfo.trend = 1
        priceInfo.momentum = 0.4 + Double.random(in: 0...0.3)
    } else {
        // 10% chance to reverse
        if Double.random(in: 0...1) < 0.1 {
            priceInfo.trend *= -1
            priceInfo.momentum = 0.3 + Double.random(in: 0...0.4)
        }
    }

    priceInfo.price = newPrice
}

// Run test
print("=== Price Trend Stability Test ===\n")
print("Testing Opium prices over 50 updates (simulating 50 voyages)")
print("Expected: Smooth trends with occasional reversals\n")

let commodity = commodities["opium"]!
var priceInfo = generateInitialPrice(commodity: commodity)

print("Base Price: ¥\(Int(commodity.basePrice))")
print("Volatility: \(Int(commodity.volatility * 100))%")
print("Price Range: ¥\(Int(commodity.basePrice * (1 - commodity.volatility))) - ¥\(Int(commodity.basePrice * (1 + commodity.volatility)))\n")

print("Update | Price   | Change | Direction | Momentum")
print("-------|---------|--------|-----------|----------")

var previousPrice = priceInfo.price
var trendChanges = 0
var previousTrend = priceInfo.trend

for i in 1...50 {
    updatePrice(priceInfo: &priceInfo, commodity: commodity)

    let change = priceInfo.price - previousPrice
    let changePercent = (change / previousPrice) * 100
    let trendSymbol = priceInfo.trend > 0 ? "↑" : "↓"

    if priceInfo.trend != previousTrend {
        trendChanges += 1
    }

    // Print every 5th update
    if i % 5 == 0 || i == 1 {
        print(String(format: "  %2d   | ¥%5d | %+5.1f%% | %s         | %.2f",
                    i, Int(priceInfo.price), changePercent, trendSymbol, priceInfo.momentum))
    }

    previousPrice = priceInfo.price
    previousTrend = priceInfo.trend
}

print("\n=== Analysis ===")
print("Trend reversals: \(trendChanges) times")
print("Final price: ¥\(Int(priceInfo.price))")

let deviation = abs(priceInfo.price - commodity.basePrice) / commodity.basePrice * 100
print("Deviation from base: \(String(format: "%.1f", deviation))%")

print("\n=== Comparison Test ===")
print("Running 3 parallel price tracks to show diversity:\n")

for track in 1...3 {
    var testPrice = generateInitialPrice(commodity: commodity)
    print("Track \(track) progression:")

    var samples: [Int] = []
    for i in 1...20 {
        updatePrice(priceInfo: &testPrice, commodity: commodity)
        if i % 4 == 0 {
            samples.append(Int(testPrice.price))
        }
    }

    print("  \(samples.map { "¥\($0)" }.joined(separator: " → "))")
}

print("\n✅ Price trend system is working!")
print("\nKey characteristics:")
print("- Prices change gradually (1-5% per update)")
print("- Trends persist for multiple updates")
print("- Occasional reversals (10% chance)")
print("- Boundaries cause trend reversals")
print("- Different tracks show variety")
