export function _tax_rate(input) {
  const t1 = 0.15;
  return t1;
}

export function _tax(input) {
  let t2 = input["amount"];
  const t3 = 0.15;
  let t4 = t2 * t3;
  return t4;
}

export function _final_total(input) {
  let t5 = input["price"];
  let t8 = input["amount"];
  const t9 = 0.15;
  let t10 = t8 * t9;
  let t7 = t5 + t10;
  return t7;
}

