module lmsr::lmsr;

use interest_math::fixed18::{Self, Fixed18};
use interest_math::i256::{Self, I256};
use interest_math::u64;

// === Error Constants ===

const EInvalidLiquidityParam: u64 = 0;
const EEmptyOutcomesQuantities: u64 = 1;
const EInvalidOutcomesQuantities: u64 = 2;
const EInvalidOutcomeQuantityIndex: u64 = 3;
const EOutcomeQuantityOverflow: u64 = 4;

/// Calculate LMSR cost function: C(q) = b * ln(Σe^(qi/b))
public fun base_cost(quantities: vector<u64>, liquidity_param: u64, decimals: u8): u64 {
    assert!(!quantities.is_empty(), EEmptyOutcomesQuantities);
    assert!(liquidity_param != 0, EInvalidLiquidityParam);

    let liquidity_param_scaled = fixed18::from_u64(liquidity_param);
    let quantities_scaled = quantities.map!(|q| fixed18::from_u64(q));
    liquidity_param_scaled
        .mul_down(log_sum_exp_scaled(quantities_scaled, liquidity_param_scaled))
        .to_u64(decimals)
}

public fun price(quantities: vector<u64>, index: u64, liquidity_param: u64, decimals: u8): u64 {
    assert!(!quantities.is_empty(), EEmptyOutcomesQuantities);
    assert!(liquidity_param != 0, EInvalidLiquidityParam);
    assert!(index < quantities.length(), EInvalidOutcomeQuantityIndex);

    let liquidity_param_scaled = fixed18::from_u64(liquidity_param);
    let quantities_scaled = quantities.map!(|q| fixed18::from_u64(q));

    let (scaled_exps, _) = scaled_exps(quantities_scaled, liquidity_param_scaled);
    scaled_exps[index].div_down(vec_fixed18_sum!(scaled_exps)).to_u64(decimals)
}

/// Calculate all outcome prices simultaneously for efficiency
/// Returns vector of prices that sum to 1.0 within tolerance
public fun prices(quantities: vector<u64>, liquidity_param: u64, decimals: u8): vector<u64> {
    assert!(!quantities.is_empty(), EEmptyOutcomesQuantities);
    assert!(liquidity_param != 0, EInvalidLiquidityParam);

    let liquidity_param_scaled = fixed18::from_u64(liquidity_param);
    let quantities_scaled = quantities.map!(|q| fixed18::from_u64(q));

    let (scaled_exps, _) = scaled_exps(quantities_scaled, liquidity_param_scaled);

    let sum_exp = vec_fixed18_sum!(scaled_exps);
    scaled_exps.map!(|scaled_exp| scaled_exp.div_down(sum_exp)).map!(|price| price.to_u64(decimals))
}

/// Calculate cost to purchase specific number of quantities for given outcome
public fun cost(
    index: u64,
    quantity: u64,
    quantities: vector<u64>,
    liquidity_param: u64,
    decimals: u8,
): u64 {
    assert!(!quantities.is_empty(), EEmptyOutcomesQuantities);
    assert!(quantity != 0, EInvalidOutcomesQuantities);
    assert!(liquidity_param != 0, EInvalidLiquidityParam);
    assert!(index < quantities.length(), EInvalidOutcomeQuantityIndex);

    let current_cost = base_cost(quantities, liquidity_param, decimals);

    let mut i = 0;
    let new_quantities = quantities.map!(|current| {
        let new_quantity = if (i == index) {
            let (success, result) = u64::try_add(current, quantity);
            assert!(success, EOutcomeQuantityOverflow);
            result
        } else {
            current
        };

        i = i + 1;
        new_quantity
    });

    base_cost(new_quantities, liquidity_param, decimals) - current_cost
}

/// Calculate payout for selling specific number of quantities for given outcome
public fun payout(
    index: u64,
    quantity: u64,
    quantities: vector<u64>,
    liquidity_param: u64,
    decimals: u8,
): u64 {
    assert!(!quantities.is_empty(), EEmptyOutcomesQuantities);
    assert!(quantity != 0, EInvalidOutcomesQuantities);
    assert!(liquidity_param != 0, EInvalidLiquidityParam);
    assert!(index < quantities.length(), EInvalidOutcomeQuantityIndex);
    assert!(quantities[index] >= quantity, EInvalidOutcomesQuantities);

    let current_cost = base_cost(quantities, liquidity_param, decimals);

    let mut i = 0;
    let new_quantities = quantities.map!(|current| {
        let new_quantity = if (i == index) {
            current - quantity
        } else {
            current
        };

        i = i + 1;
        new_quantity
    });

    current_cost - base_cost(new_quantities, liquidity_param, decimals)
}

// === Private Functions ===

/// Implement log-sum-exp trick: LSE(x) = max(x) + ln(Σe^(xi - max(x)))
fun log_sum_exp_scaled(quantities: vector<Fixed18>, liquidity_param: Fixed18): Fixed18 {
    let scaled_quantities = scale_quantities_by_liquidity(quantities, liquidity_param);
    let max_scaled = vec_i256_max!(scaled_quantities);

    let mut sum_exp = i256::zero();
    scaled_quantities.do_ref!(|scaled_quantity| {
        let diff = (*scaled_quantity).sub(max_scaled);
        sum_exp = sum_exp.add(diff.exp());
    });

    fixed18::from_raw_u256(max_scaled.add(sum_exp.ln()).to_u256())
}

/// Calculate e^(qi/b) for all outcomes using numerical stability techniques
/// Returns (scaled_exponentials, max_scaled_value)
fun scaled_exps(quantities: vector<Fixed18>, liquidity_param: Fixed18): (vector<Fixed18>, I256) {
    let scaled_quantities = scale_quantities_by_liquidity(quantities, liquidity_param);

    let max_scaled = vec_i256_max!(scaled_quantities);
    let scaled_exps = scaled_quantities.map!(
        |scaled_quantity| fixed18::from_raw_u256(scaled_quantity.sub(max_scaled).exp().to_u256()),
    );

    (scaled_exps, max_scaled)
}

fun scale_quantities_by_liquidity(
    quantities: vector<Fixed18>,
    liquidity_param: Fixed18,
): vector<I256> {
    quantities.map!(|quantity| {
        let scaled_fixed18 = quantity.div_down(liquidity_param);
        assert!(scaled_fixed18.raw_value() <= max_safe_exp_input!(), EOutcomeQuantityOverflow);
        i256::from_u256(scaled_fixed18.raw_value())
    })
}

macro fun vec_i256_max($values: vector<I256>): I256 {
    let values = $values;
    let mut max_value = values[0];

    values.do!(|value| if (value.gt(max_value)) max_value = value);
    max_value
}

macro fun vec_fixed18_sum($values: vector<Fixed18>): Fixed18 {
    let values = $values;
    values.fold!(fixed18::zero(), |acc, value| acc.add(value))
}

/// Maximum safe input for exp function (100 * 10^18 in Fixed18 format)
macro fun max_safe_exp_input(): u256 {
    100_000_000_000_000_000_000
}
