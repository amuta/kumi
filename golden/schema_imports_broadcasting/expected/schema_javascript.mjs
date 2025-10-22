export function _tax_rate(input) {
  const t1 = 0.15;
  return t1;
}

export function _item_taxes(input) {
  let out = [];
  let t2 = input["items"];
  const t6 = 0.15;
  t2.forEach((items_el_3, items_i_4) => {
    let t5 = items_el_3["price"];
    let t7 = t5 * t6;
    out.push(t7);
  });
  return out;
}

