export function _order_subtotal(input) {
  let t8 = input["order_items"];
  let acc13 = 0;
  for (let order_items_i10 = 0; order_items_i10 < t8.length; order_items_i10++) {
    let order_items_el9 = t8[order_items_i10];
    let t11 = order_items_el9["quantity"];
    let t12 = order_items_el9["unit_price"];
    let t6 = t11 * t12;
    acc13 += t6;
  }
  let t7 = acc13;
  return t7;
}

export function _tax_amount(input) {
  let t13 = input["order_items"];
  let acc18 = 0;
  for (let order_items_i15 = 0; order_items_i15 < t13.length; order_items_i15++) {
    let order_items_el14 = t13[order_items_i15];
    let t16 = order_items_el14["quantity"];
    let t17 = order_items_el14["unit_price"];
    let t11 = t16 * t17;
    acc18 += t11;
  }
  let t12 = acc18;
  let t19 = input["tax_rate"];
  let t5 = t12 * t19;
  return t5;
}

export function _total(input) {
  let t20 = input["order_items"];
  let acc25 = 0;
  for (let order_items_i22 = 0; order_items_i22 < t20.length; order_items_i22++) {
    let order_items_el21 = t20[order_items_i22];
    let t23 = order_items_el21["quantity"];
    let t24 = order_items_el21["unit_price"];
    let t18 = t23 * t24;
    acc25 += t18;
  }
  let t19 = acc25;
  let t26 = input["tax_rate"];
  let t14 = t19 * t26;
  let t8 = t19 + t14;
  return t8;
}

