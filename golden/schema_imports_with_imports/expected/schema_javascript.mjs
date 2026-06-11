export function _tax_result(input) {
  let t5 = input["amount"];
  let t6 = 0.15;
  let t4 = t5 * t6;
  return t4;
}

export function _total(input) {
  let t10 = input["amount"];
  let t11 = 0.15;
  let t9 = t10 * t11;
  let t5 = t10 + t9;
  return t5;
}

