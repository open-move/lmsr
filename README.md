# LMSR

An implementation of the Logarithmic Market Scoring Rule (LMSR) in Sui Move.

LMSR is an automated market maker designed for prediction markets. It provides continuous liquidity and automatic price discovery which ensures that traders can always buy or sell outcome shares while maintaining proper probabilistic pricing that sums to 1.

## Installation

Add to your `Move.toml`:

```toml
[dependencies]

lmsr = { git = "https://github.com/open-move/lmsr.git", rev = "main" }
```

```bash
sui move build
sui move test
```

## Usage

```rust
use lmsr::lmsr;

// Create market with 3 outcomes
let liquidity = 1000;  // Higher = more stable prices
let quantities = vector[100, 100, 100];

// Get all prices (sum to 1.0)
let prices = lmsr::prices(quantities, liquidity);

// Cost to buy 50 shares of outcome 1
let cost = lmsr::cost(1, 50, quantities, liquidity);
quantities[1] = quantities[1] + 50;

// Payout for selling 20 shares of outcome 1
let payout = lmsr::payout(1, 20, quantities, liquidity);
```

## Functions

- `base_cost(quantities, b)` - Total market cost
- `price(quantities, index, b)` - Single outcome price
- `prices(quantities, b)` - All outcome prices
- `cost(index, amount, quantities, b)` - Buy cost
- `payout(index, amount, quantities, b)` - Sell payout

## Build & Test
