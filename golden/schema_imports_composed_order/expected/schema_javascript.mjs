export function _subtotal(input) {
  let t1 = input["item_price"];
  let t2 = input["quantity"];
  let t3 = t1 * t2;
  return t3;
}

export function _price_after_discount(input) {
  let t12 = input["item_price"];
  let t13 = input["quantity"];
  let t14 = t12 * t13;
  let t5 = input["discount_rate"];
  let t6 = GoldenSchemas.Price.from({'base_price': t14, 'discount_rate': t5})._discounted;
  return t6;
}

export function _discount_amt(input) {
  let t15 = input["item_price"];
  let t16 = input["quantity"];
  let t17 = t15 * t16;
  let t8 = input["discount_rate"];
  let t9 = GoldenSchemas.Price.from({'base_price': t17, 'discount_rate': t8})._discount_amount;
  return t9;
}

export function _final_total(input) {
  let t21 = input["item_price"];
  let t22 = input["quantity"];
  let t23 = t21 * t22;
  let t19 = input["discount_rate"];
  let t20 = GoldenSchemas.Price.from({'base_price': t23, 'discount_rate': t19})._discounted;
  let t11 = GoldenSchemas.Tax.from({'amount': t20})._total;
  return t11;
}

