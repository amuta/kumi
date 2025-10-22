export function _order_subtotals(input) {
  let out = [];
  let t1 = input["orders"];
  t1.forEach((orders_el_2, orders_i_3) => {
    let t4 = orders_el_2["items"];
    let t5 = GoldenSchemas.Subtotal.from({'items': t4})._subtotal;
    out.push(t5);
  });
  return out;
}

export function _total_before_tax(input) {
  let acc_6 = 0;
  let t7 = input["orders"];
  t7.forEach((orders_el_8, orders_i_9) => {
    let t18 = orders_el_8["items"];
    let t19 = GoldenSchemas.Subtotal.from({'items': t18})._subtotal;
    acc_6 += t19;
  });
  return acc_6;
}

export function _tax_for_all(input) {
  let acc21 = 0;
  let t22 = input["orders"];
  t22.forEach((t23, t24) => {
    let t28 = t23["items"];
    let t29 = GoldenSchemas.Subtotal.from({'items': t28})._subtotal;
    acc21 += t29;
  });
  let t13 = GoldenSchemas.Tax.from({'amount': acc21})._tax;
  return t13;
}

export function _grand_total(input) {
  let acc31 = 0;
  let t32 = input["orders"];
  let acc43 = 0;
  t32.forEach((t33, t34) => {
    let t38 = t33["items"];
    let t39 = GoldenSchemas.Subtotal.from({'items': t38})._subtotal;
    acc31 += t39;
    acc43 += t39;
  });
  let t41 = GoldenSchemas.Tax.from({'amount': acc43})._tax;
  let t16 = acc31 + t41;
  return t16;
}

