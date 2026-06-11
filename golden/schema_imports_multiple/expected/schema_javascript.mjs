export function _tax_amount(input) {
  let t5 = input["amount"];
  let t6 = 0.15;
  let t4 = t5 * t6;
  return t4;
}

export function _price_after_tax(input) {
  let t10 = input["amount"];
  let t11 = 0.15;
  let t9 = t10 * t11;
  let t5 = t10 + t9;
  return t5;
}

export function _discounted_price(input) {
  let t18 = input["amount"];
  let t19 = 0.15;
  let t14 = t18 * t19;
  let t12 = t18 + t14;
  let t20 = 1.0;
  let t21 = input["discount_rate"];
  let t16 = t20 - t21;
  let t17 = t12 * t16;
  return t17;
}

export function _discount_amount(input) {
  let t19 = input["amount"];
  let t20 = 0.15;
  let t17 = t19 * t20;
  let t15 = t19 + t17;
  let t21 = input["discount_rate"];
  let t18 = t15 * t21;
  return t18;
}

export function _final_price(input) {
  let t24 = input["amount"];
  let t25 = 0.15;
  let t20 = t24 * t25;
  let t16 = t24 + t20;
  let t26 = 1.0;
  let t27 = input["discount_rate"];
  let t22 = t26 - t27;
  let t23 = t16 * t22;
  return t23;
}

