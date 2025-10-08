#[test_only]
module lmsr::lmsr_tests;

use lmsr::lmsr;
use std::unit_test::assert_eq;

#[test]
fun test_base_cost() {
    let decimals = 6u8;
    let scale = 10u64.pow(decimals);
    let liquidity = 1000 * scale;
    let quantities = vector[100 * scale, 100 * scale];
    let cost = lmsr::base_cost(quantities, liquidity, decimals);

    // A combination the above parameters should always yield a certain base cost
    assert_eq!(cost, 793147180);
}

#[test]
fun test_prices_initial() {
    let liquidity = 1000;
    let quantities = vector[0, 0];
    let decimals = 6u8;

    let price_0 = lmsr::price(quantities, 0, liquidity, decimals);
    let price_1 = lmsr::price(quantities, 1, liquidity, decimals);

    // Both outcomes should have equal price initially
    assert_eq!(price_0, price_1);
    assert_eq!(price_0, 10u64.pow(decimals) / 2);
}

#[test]
fun test_prices_summation() {
    let liquidity = 1000;
    let quantities = vector[100, 150, 200];
    let decimals = 6u8;

    let prices = lmsr::prices(quantities, liquidity, decimals);
    let prices_sum = prices.fold!(0, |acc, x| acc + x);

    std::debug::print(&prices);
    std::debug::print(&(prices_sum+2));

    let tolerance = 10; // Allow small rounding error
    let one = 10u64.pow(decimals);
    assert!(prices_sum >= one - tolerance && prices_sum <= one + tolerance);
}

#[test]
fun test_const_difference() {
    let quantities = vector[5_00_000, 5_00_000];
    let liquidity = 1000 * 1000000;
    let decimals = 6u8;

    // Cost for different quantities
    let cost_10 = lmsr::cost(0, 5_000_000, quantities, liquidity, decimals);
    let cost_20 = lmsr::cost(0, 7_000_000, quantities, liquidity, decimals);
    std::debug::print(&cost_10);
    std::debug::print(&cost_20);

    assert!(cost_20 > cost_10);
}

#[test, expected_failure(abort_code = lmsr::EEmptyOutcomesQuantities)]
fun test_empty_quantities_fails() {
    let empty = vector[];
    let liquidity = 1000;
    let decimals = 6u8;
    lmsr::base_cost(empty, liquidity, decimals);
}

#[test, expected_failure(abort_code = lmsr::EInvalidLiquidityParam)]
fun test_zero_liquidity_fails() {
    let quantities = vector[100, 100];
    let decimals = 6u8;
    lmsr::base_cost(quantities, 0, decimals);
}

#[test, expected_failure(abort_code = lmsr::EInvalidOutcomeQuantityIndex)]
fun test_invalid_index_fails() {
    let quantities = vector[100, 100];
    let liquidity = 1000;
    let decimals = 6u8;

    // Try to get price for non-existent outcome 2
    lmsr::price(quantities, 2, liquidity, decimals);
}

#[test, expected_failure(abort_code = lmsr::EInvalidOutcomesQuantities)]
fun test_sell_more_than_available_fails() {
    let quantities = vector[50, 100];
    let liquidity = 1000;
    let decimals = 6u8;

    // Try to sell 100 when only 50 available
    lmsr::payout(0, 100, quantities, liquidity, decimals);
}

// === Boundary Condition Tests ===

#[test]
fun test_single_outcome_market() {
    let quantities = vector[100];
    let liquidity = 1000;
    let decimals = 6u8;

    let cost = lmsr::base_cost(quantities, liquidity, decimals);
    assert!(cost > 0);

    let price = lmsr::price(quantities, 0, liquidity, decimals);
    // Single outcome should have price of 1.0 (scaled by decimals)
    assert_eq!(price, 10u64.pow(decimals));
}

#[test]
fun test_large_quantities() {
    let quantities = vector[1000000, 2000000, 3000000];
    let liquidity = 10000;
    let decimals = 6u8;

    let cost = lmsr::base_cost(quantities, liquidity, decimals);
    assert!(cost > 0);

    let prices = lmsr::prices(quantities, liquidity, decimals);
    let sum = prices.fold!(0, |acc, x| acc + x);
    let one = 10u64.pow(decimals);
    let tolerance = 100; // Allow for rounding with large numbers
    assert!(sum >= one - tolerance && sum <= one + tolerance);
}

#[test]
fun test_very_small_liquidity() {
    let quantities = vector[10, 10];
    let liquidity = 1; // Minimal liquidity
    let decimals = 6u8;

    let cost = lmsr::base_cost(quantities, liquidity, decimals);
    assert!(cost > 0);

    let prices = lmsr::prices(quantities, liquidity, decimals);
    assert_eq!(prices.length(), 2);
}

#[test]
fun test_zero_quantities() {
    let quantities = vector[0, 0, 0];
    let liquidity = 1000;
    let decimals = 6u8;

    let cost = lmsr::base_cost(quantities, liquidity, decimals);
    assert!(cost > 0);

    let prices = lmsr::prices(quantities, liquidity, decimals);
    // All prices should be equal for zero quantities
    let expected_price = 10u64.pow(decimals) / 3;
    let tolerance = 10;
    prices.do_ref!(|price| {
        assert!(*price >= expected_price - tolerance && *price <= expected_price + tolerance);
    });
}

#[test]
fun test_uneven_quantities() {
    let quantities = vector[1, 1000, 10];
    let liquidity = 1000;
    let decimals = 6u8;

    let prices = lmsr::prices(quantities, liquidity, decimals);

    // Outcome with highest quantity (index 1) should have highest price
    assert!(prices[1] > prices[0]);
    assert!(prices[1] > prices[2]);
}

// === Mathematical Property Tests ===

#[test]
fun test_increasing_cost_property() {
    let quantities = vector[100, 100];
    let liquidity = 1000;
    let decimals = 6u8;

    // Buying more of the same outcome should cost increasingly more
    let cost_5 = lmsr::cost(0, 5, quantities, liquidity, decimals);
    let cost_10 = lmsr::cost(0, 10, quantities, liquidity, decimals);
    let cost_20 = lmsr::cost(0, 20, quantities, liquidity, decimals);

    assert!(cost_10 > cost_5);
    assert!(cost_20 > cost_10);

    // Cost per share should increase (convex cost function)
    assert!(cost_10 > 2 * cost_5); // More than double cost for double quantity
}

#[test]
fun test_price_consistency() {
    let quantities = vector[100, 200, 50];
    let liquidity = 1000;
    let decimals = 6u8;

    // Individual price calls should match prices array
    let prices_array = lmsr::prices(quantities, liquidity, decimals);
    let price_0 = lmsr::price(quantities, 0, liquidity, decimals);
    let price_1 = lmsr::price(quantities, 1, liquidity, decimals);
    let price_2 = lmsr::price(quantities, 2, liquidity, decimals);

    assert_eq!(prices_array[0], price_0);
    assert_eq!(prices_array[1], price_1);
    assert_eq!(prices_array[2], price_2);
}

#[test]
fun test_liquidity_effect_on_prices() {
    let quantities = vector[100, 200];
    let decimals = 6u8;

    // Higher liquidity should make prices more stable (closer to each other)
    let prices_low_liq = lmsr::prices(quantities, 100, decimals);
    let prices_high_liq = lmsr::prices(quantities, 10000, decimals);

    let diff_low = if (prices_low_liq[1] > prices_low_liq[0]) {
        prices_low_liq[1] - prices_low_liq[0]
    } else {
        prices_low_liq[0] - prices_low_liq[1]
    };

    let diff_high = if (prices_high_liq[1] > prices_high_liq[0]) {
        prices_high_liq[1] - prices_high_liq[0]
    } else {
        prices_high_liq[0] - prices_high_liq[1]
    };

    // High liquidity should result in smaller price differences
    assert!(diff_high < diff_low);
}

#[test]
fun test_base_cost_monotonicity() {
    let liquidity = 1000;
    let decimals = 6u8;

    // Base cost should increase when quantities increase
    let cost_1 = lmsr::base_cost(vector[10, 10], liquidity, decimals);
    let cost_2 = lmsr::base_cost(vector[20, 10], liquidity, decimals);
    let cost_3 = lmsr::base_cost(vector[20, 20], liquidity, decimals);

    assert!(cost_2 > cost_1);
    assert!(cost_3 > cost_2);
}

// === Decimal Precision Tests ===

#[test]
fun test_different_decimal_precisions() {
    let quantities = vector[100, 200, 150];
    let liquidity = 1000;

    // Test various decimal precisions (minimum 6)
    let prices_6 = lmsr::prices(quantities, liquidity, 6u8);
    std::debug::print(&prices_6);
    let prices_9 = lmsr::prices(quantities, liquidity, 9u8);
    std::debug::print(&prices_9);
    let prices_12 = lmsr::prices(quantities, liquidity, 12u8);
    std::debug::print(&prices_12);
    let _prices_18 = lmsr::prices(quantities, liquidity, 18u8);
    std::debug::print(&_prices_18);

    // Higher decimals should provide finer granularity
    assert!(prices_9[0] >= prices_6[0] * 1000);
    assert!(prices_12[0] >= prices_9[0] * 1000);

    // Prices should still sum to 1 (scaled by decimals)
    let tolerance_6 = 10u64; // 0.00001 tolerance for 6 decimals
    let sum_6 = prices_6.fold!(0, |acc, x| acc + x);
    assert!(sum_6 >= 10u64.pow(6) - tolerance_6 && sum_6 <= 10u64.pow(6) + tolerance_6);

    let tolerance_9 = 1000u64; // Similar relative tolerance for 9 decimals
    let sum_9 = prices_9.fold!(0, |acc, x| acc + x);
    assert!(sum_9 >= 10u64.pow(9) - tolerance_9 && sum_9 <= 10u64.pow(9) + tolerance_9);
}

// === Additional Error Condition Tests ===

#[test, expected_failure(abort_code = lmsr::EInvalidOutcomesQuantities)]
fun test_zero_cost_fails() {
    let quantities = vector[100, 100];
    let liquidity = 1000;
    let decimals = 6u8;

    // Try to buy 0 shares (should fail)
    lmsr::cost(0, 0, quantities, liquidity, decimals);
}

#[test, expected_failure(abort_code = lmsr::EInvalidOutcomesQuantities)]
fun test_zero_payout_fails() {
    let quantities = vector[100, 100];
    let liquidity = 1000;
    let decimals = 6u8;

    // Try to sell 0 shares (should fail)
    lmsr::payout(0, 0, quantities, liquidity, decimals);
}

#[test, expected_failure(abort_code = lmsr::EInvalidOutcomeQuantityIndex)]
fun test_cost_invalid_index_fails() {
    let quantities = vector[100, 100];
    let liquidity = 1000;
    let decimals = 6u8;

    // Try to buy shares for non-existent outcome
    lmsr::cost(5, 10, quantities, liquidity, decimals);
}

#[test, expected_failure(abort_code = lmsr::EInvalidOutcomeQuantityIndex)]
fun test_payout_invalid_index_fails() {
    let quantities = vector[100, 100];
    let liquidity = 1000;
    let decimals = 6u8;

    // Try to sell shares for non-existent outcome
    lmsr::payout(5, 10, quantities, liquidity, decimals);
}

#[test, expected_failure(abort_code = lmsr::EOutcomeQuantityOverflow)]
fun test_large_quantity_overflow() {
    let quantities = vector[18446744073709551615u64]; // Max u64
    let liquidity = 1000;
    let decimals = 6u8;

    // Try to buy 1 more share (should overflow)
    lmsr::cost(0, 1, quantities, liquidity, decimals);
}

#[test, expected_failure(abort_code = lmsr::EInvalidLiquidityParam)]
fun test_price_zero_liquidity_fails() {
    let quantities = vector[100, 100];
    let decimals = 6u8;

    // Try to get price with zero liquidity
    lmsr::price(quantities, 0, 0, decimals);
}

#[test, expected_failure(abort_code = lmsr::EInvalidLiquidityParam)]
fun test_prices_zero_liquidity_fails() {
    let quantities = vector[100, 100];
    let decimals = 6u8;

    // Try to get prices with zero liquidity
    lmsr::prices(quantities, 0, decimals);
}

#[test, expected_failure(abort_code = lmsr::EInvalidLiquidityParam)]
fun test_cost_zero_liquidity_fails() {
    let quantities = vector[100, 100];
    let decimals = 6u8;

    // Try to get cost with zero liquidity
    lmsr::cost(0, 10, quantities, 0, decimals);
}

#[test, expected_failure(abort_code = lmsr::EInvalidLiquidityParam)]
fun test_payout_zero_liquidity_fails() {
    let quantities = vector[100, 100];
    let decimals = 6u8;

    // Try to get payout with zero liquidity
    lmsr::payout(0, 10, quantities, 0, decimals);
}
