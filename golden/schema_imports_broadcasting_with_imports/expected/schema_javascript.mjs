export function _item_taxes(input) {
  let out = [];
  let t1 = input["items"];
  const t5 = 0.15;
  t1.forEach((items_el_2, items_i_3) => {
    let t4 = items_el_2["amount"];
    let t6 = t4 * t5;
    out.push(t6);
  });
  return out;
}

export function _total_tax(input) {
  let acc_7 = 0.0;
  let t8 = input["items"];
  const t15 = 0.15;
  t8.forEach((items_el_9, items_i_10) => {
    let t14 = items_el_9["amount"];
    let t16 = t14 * t15;
    acc_7 += t16;
  });
  return acc_7;
}

