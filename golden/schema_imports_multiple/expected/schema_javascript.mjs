export function _tax_amount(input) {
  let t1 = input["amount"];
  let t2 = GoldenSchemas.Tax.from({'amount': t1})._tax;
  return t2;
}

export function _price_after_tax(input) {
  let t3 = input["amount"];
  let t14 = GoldenSchemas.Tax.from({'amount': t3})._tax;
  let t5 = t3 + t14;
  return t5;
}

export function _discounted_price(input) {
  let t15 = input["amount"];
  let t19 = GoldenSchemas.Tax.from({'amount': t15})._tax;
  let t17 = t15 + t19;
  let t7 = input["discount_rate"];
  let t8 = GoldenSchemas.Discount.from({'price': t17, 'rate': t7})._discounted;
  return t8;
}

export function _discount_amount(input) {
  let t20 = input["amount"];
  let t24 = GoldenSchemas.Tax.from({'amount': t20})._tax;
  let t22 = t20 + t24;
  let t10 = input["discount_rate"];
  let t11 = GoldenSchemas.Discount.from({'price': t22, 'rate': t10})._savings;
  return t11;
}

export function _final_price(input) {
  let t28 = input["amount"];
  let t32 = GoldenSchemas.Tax.from({'amount': t28})._tax;
  let t30 = t28 + t32;
  let t26 = input["discount_rate"];
  let t27 = GoldenSchemas.Discount.from({'price': t30, 'rate': t26})._discounted;
  return t27;
}

