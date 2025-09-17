#[test_only]
module lmsr::lmsr_tests;

use lmsr::lmsr;
use std::unit_test::assert_eq;

#[test]
fun test_base_cost() {
    let liquidity = 1000;
    let quantities = vector[100, 100];
    let cost = lmsr::base_cost(quantities, liquidity);

    // A combination the above parameters should always yield a certain base cost
    assert_eq!(cost, 793147180);
}

#[test]
fun test_prices_initial() {
    let liquidity = 1000;
    let quantities = vector[0, 0];

    let price_0 = lmsr::price(quantities, 0, liquidity);
    let price_1 = lmsr::price(quantities, 1, liquidity);

    // Both outcomes should have equal price initially
    assert_eq!(price_0, price_1);
    assert_eq!(price_0, 10u64.pow(lmsr::precision_decimals!()) / 2);
}

#[test]
fun test_prices_summation() {
    let liquidity = 1000;
    let quantities = vector[100, 150, 200];

    let prices = lmsr::prices(quantities, liquidity);
    let prices_sum = prices.fold!(0, |acc, x| acc + x);

    let tolerance = 10; // Allow small rounding error
    let one = 10u64.pow(lmsr::precision_decimals!());
    assert!(prices_sum >= one - tolerance && prices_sum <= one + tolerance);
}

#[test]
fun test_const_difference() {
    let quantities = vector[100, 100];
    let liquidity = 1000;

    // Cost for different quantities
    let cost_10 = lmsr::cost(0, 10, quantities, liquidity);
    let cost_20 = lmsr::cost(0, 20, quantities, liquidity);
    assert!(cost_20 > cost_10);
}

#[test, expected_failure(abort_code = lmsr::EEmptyOutcomesQuantities)]
fun test_empty_quantities_fails() {
    let empty = vector[];
    let liquidity = 1000;
    lmsr::base_cost(empty, liquidity);
}

#[test, expected_failure(abort_code = lmsr::EInvalidLiquidityParam)]
fun test_zero_liquidity_fails() {
    let quantities = vector[100, 100];
    lmsr::base_cost(quantities, 0);
}

#[test, expected_failure(abort_code = lmsr::EInvalidOutcomeQuantityIndex)]
fun test_invalid_index_fails() {
    let quantities = vector[100, 100];
    let liquidity = 1000;

    // Try to get price for non-existent outcome 2
    lmsr::price(quantities, 2, liquidity);
}

#[test, expected_failure(abort_code = lmsr::EInvalidOutcomesQuantities)]
fun test_sell_more_than_available_fails() {
    let quantities = vector[50, 100];
    let liquidity = 1000;

    // Try to sell 100 when only 50 available
    lmsr::payout(0, 100, quantities, liquidity);
}
