export function _items_subtotal(input) {
  let out = [];
  let t1 = input["items"];
  t1.forEach((items_el_2, items_i_3) => {
    let t4 = items_el_2["price"];
    let t5 = items_el_2["qty"];
    let t6 = t4 * t5;
    out.push(t6);
  });
  return out;
}

export function _items_discounted(input) {
  let out = [];
  let t7 = input["items"];
  let t12 = input["discount"];
  let t13 = 1.0 - t12;
  t7.forEach((items_el_8, items_i_9) => {
    let t10 = items_el_8["price"];
    let t14 = t10 * t13;
    out.push(t14);
  });
  return out;
}

export function _items_is_big(input) {
  let out = [];
  let t15 = input["items"];
  t15.forEach((items_el_16, items_i_17) => {
    let t18 = items_el_16["price"];
    let t20 = t18 > 100.0;
    out.push(t20);
  });
  return out;
}

export function _items_effective(input) {
  let out = [];
  let t21 = input["items"];
  t21.forEach((items_el_22, items_i_23) => {
    let t49 = items_el_22["price"];
    let t54 = items_el_22["qty"];
    let t51 = t49 > 100.0;
    let t55 = t49 * t54;
    let t27 = t55 * 0.9;
    let t29 = t51 ? t27 : t55;
    out.push(t29);
  });
  return out;
}

export function _total_qty(input) {
  let acc_30 = 0.0;
  let t31 = input["items"];
  t31.forEach((items_el_32, items_i_33) => {
    let t34 = items_el_32["qty"];
    acc_30 += t34;
  });
  return acc_30;
}

export function _cart_total(input) {
  let acc_36 = 0.0;
  let t37 = input["items"];
  t37.forEach((items_el_38, items_i_39) => {
    let t61 = items_el_38["price"];
    let t62 = items_el_38["qty"];
    let t63 = t61 * t62;
    acc_36 += t63;
  });
  return acc_36;
}

export function _cart_total_effective(input) {
  let acc_42 = 0.0;
  let t43 = input["items"];
  t43.forEach((items_el_44, items_i_45) => {
    let t72 = items_el_44["price"];
    let t77 = items_el_44["qty"];
    let t74 = t72 > 100.0;
    let t78 = t72 * t77;
    let t68 = t78 * 0.9;
    let t70 = t74 ? t68 : t78;
    acc_42 += t70;
  });
  return acc_42;
}

