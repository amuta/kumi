export function _item_taxes(input) {
  let t7 = input["items"];
  let arr12 = [];
  for (let items_i9 = 0; items_i9 < t7.length; items_i9++) {
    let items_el8 = t7[items_i9];
    let t10 = items_el8["amount"];
    let t11 = 0.15;
    let t6 = t10 * t11;
    arr12.push(t6);
  }
  return arr12;
}

export function _total_tax(input) {
  let t13 = input["items"];
  let acc18 = 0.0;
  for (let items_i15 = 0; items_i15 < t13.length; items_i15++) {
    let items_el14 = t13[items_i15];
    let t16 = items_el14["amount"];
    let t17 = 0.15;
    let t12 = t16 * t17;
    acc18 += t12;
  }
  let t6 = acc18;
  return t6;
}

