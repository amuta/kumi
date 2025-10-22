export function _tax_result(input) {
  let t1 = input["amount"];
  let t2 = GoldenSchemas.Tax.from({'amount': t1})._tax;
  return t2;
}

export function _total(input) {
  let t3 = input["amount"];
  let t7 = GoldenSchemas.Tax.from({'amount': t3})._tax;
  let t5 = t3 + t7;
  return t5;
}

