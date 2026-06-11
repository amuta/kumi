export function _tax_amount(input) {
  let t5 = input["price"];
  let t6 = 0.15;
  let t4 = t5 * t6;
  return t4;
}

export function _price_after_discount(input) {
  let t9 = 1.0;
  let t10 = input["discount_rate"];
  let t7 = t9 - t10;
  let t11 = input["price"];
  let t8 = t11 * t7;
  return t8;
}

export function _discount_saved(input) {
  let t10 = input["price"];
  let t11 = input["discount_rate"];
  let t9 = t10 * t11;
  return t9;
}

export function _tax_on_discounted(input) {
  let t19 = 1.0;
  let t20 = input["discount_rate"];
  let t15 = t19 - t20;
  let t21 = input["price"];
  let t16 = t21 * t15;
  let t22 = 0.15;
  let t18 = t16 * t22;
  return t18;
}

export function _final_total(input) {
  let t26 = 1.0;
  let t27 = input["discount_rate"];
  let t22 = t26 - t27;
  let t28 = input["price"];
  let t23 = t28 * t22;
  let t29 = 0.15;
  let t25 = t23 * t29;
  let t13 = t23 + t25;
  return t13;
}

