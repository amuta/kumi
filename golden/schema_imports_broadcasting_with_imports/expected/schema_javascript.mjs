export function _item_taxes(input) {
  let out = [];
  let t1 = input["items"];
  t1.forEach((items_el_2, items_i_3) => {
    let t4 = items_el_2["amount"];
    let t5 = Kumi.TestSharedSchemas.Tax.from({'amount': t4})._tax;
    out.push(t5);
  });
  return out;
}

export function _total_tax(input) {
  let acc_6 = 0.0;
  let t7 = input["items"];
  t7.forEach((items_el_8, items_i_9) => {
    let t13 = items_el_8["amount"];
    let t14 = Kumi.TestSharedSchemas.Tax.from({'amount': t13})._tax;
    acc_6 += t14;
  });
  return acc_6;
}

