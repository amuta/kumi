export function _tax_amount(input) {
  let t1 = input["price"];
  let t2 = GoldenSchemas.Tax.from({'amount': t1})._tax;
  return t2;
}

export function _price_after_discount(input) {
  let t3 = input["price"];
  let t4 = input["discount_rate"];
  let t5 = GoldenSchemas.Discount.from({'price': t3, 'rate': t4})._discounted;
  return t5;
}

export function _discount_saved(input) {
  let t6 = input["price"];
  let t7 = input["discount_rate"];
  let t8 = GoldenSchemas.Discount.from({'price': t6, 'rate': t7})._savings;
  return t8;
}

export function _tax_on_discounted(input) {
  let t14 = input["price"];
  let t15 = input["discount_rate"];
  let t16 = GoldenSchemas.Discount.from({'price': t14, 'rate': t15})._discounted;
  let t10 = GoldenSchemas.Tax.from({'amount': t16})._tax;
  return t10;
}

export function _final_total(input) {
  let t17 = input["price"];
  let t18 = input["discount_rate"];
  let t19 = GoldenSchemas.Discount.from({'price': t17, 'rate': t18})._discounted;
  let t21 = GoldenSchemas.Tax.from({'amount': t19})._tax;
  let t13 = t19 + t21;
  return t13;
}

