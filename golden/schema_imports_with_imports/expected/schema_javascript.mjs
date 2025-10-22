export function _tax_result(input) {
  let t1 = input["amount"];
  const t2 = 0.15;
  let t3 = t1 * t2;
  return t3;
}

export function _total(input) {
  let t4 = input["amount"];
  const t8 = 0.15;
  let t9 = t4 * t8;
  let t6 = t4 + t9;
  return t6;
}

