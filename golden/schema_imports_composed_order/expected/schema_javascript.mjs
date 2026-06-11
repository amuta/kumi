export function _subtotal(input) {
  let t4 = input["item_price"];
  let t5 = input["quantity"];
  let t3 = t4 * t5;
  return t3;
}

export function _price_after_discount(input) {
  let t13 = input["item_price"];
  let t14 = input["quantity"];
  let t9 = t13 * t14;
  let t15 = 1.0;
  let t16 = input["discount_rate"];
  let t11 = t15 - t16;
  let t12 = t9 * t11;
  return t12;
}

export function _discount_amt(input) {
  let t14 = input["item_price"];
  let t15 = input["quantity"];
  let t12 = t14 * t15;
  let t16 = input["discount_rate"];
  let t13 = t12 * t16;
  return t13;
}

export function _final_total(input) {
  let t23 = input["item_price"];
  let t24 = input["quantity"];
  let t14 = t23 * t24;
  let t25 = 1.0;
  let t26 = input["discount_rate"];
  let t18 = t25 - t26;
  let t19 = t14 * t18;
  let t27 = 0.15;
  let t21 = t19 * t27;
  let t22 = t19 + t21;
  return t22;
}

