# LMSR

Logarithmic Market Scoring Rule for prediction markets on Sui.

Automated market maker for prediction markets with continuous liquidity.

## Installation

Add to your `Move.toml`:
```toml
[dependencies]
lmsr = { git = "https://github.com/open-move/lmsr.git", rev = "main" }
```

## Usage

```move
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

```bash
sui move build
sui move test
```