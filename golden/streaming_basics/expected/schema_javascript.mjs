export function _items_subtotal(input) {
  let t8 = input["items"];
  let arr13 = [];
  for (let items_i10 = 0; items_i10 < t8.length; items_i10++) {
    let items_el9 = t8[items_i10];
    let t11 = items_el9["price"];
    let t12 = items_el9["qty"];
    let t7 = t11 * t12;
    arr13.push(t7);
  }
  return arr13;
}

export function _items_discounted(input) {
  let t16 = 1.0;
  let t17 = input["discount"];
  let t13 = t16 - t17;
  let t18 = input["items"];
  let arr22 = [];
  for (let items_i20 = 0; items_i20 < t18.length; items_i20++) {
    let items_el19 = t18[items_i20];
    let t21 = items_el19["price"];
    let t15 = t21 * t13;
    arr22.push(t15);
  }
  return arr22;
}

export function _items_is_big(input) {
  let t22 = input["items"];
  let arr27 = [];
  for (let items_i24 = 0; items_i24 < t22.length; items_i24++) {
    let items_el23 = t22[items_i24];
    let t25 = items_el23["price"];
    let t26 = 100.0;
    let t21 = t25 > t26;
    arr27.push(t21);
  }
  return arr27;
}

export function _items_effective(input) {
  let t42 = input["items"];
  let arr49 = [];
  for (let items_i44 = 0; items_i44 < t42.length; items_i44++) {
    let items_el43 = t42[items_i44];
    let t45 = items_el43["price"];
    let t46 = 100.0;
    let t34 = t45 > t46;
    let t47 = items_el43["qty"];
    let t41 = t45 * t47;
    let t48 = 0.9;
    let t26 = t41 * t48;
    let t28 = t34 ? t26 : t41;
    arr49.push(t28);
  }
  return arr49;
}

export function _total_qty(input) {
  let t33 = input["items"];
  let acc37 = 0;
  for (let items_i35 = 0; items_i35 < t33.length; items_i35++) {
    let items_el34 = t33[items_i35];
    let t36 = items_el34["qty"];
    acc37 += t36;
  }
  let t32 = acc37;
  return t32;
}

export function _cart_total(input) {
  let t42 = input["items"];
  let acc47 = 0.0;
  for (let items_i44 = 0; items_i44 < t42.length; items_i44++) {
    let items_el43 = t42[items_i44];
    let t45 = items_el43["price"];
    let t46 = items_el43["qty"];
    let t41 = t45 * t46;
    acc47 += t41;
  }
  let t34 = acc47;
  return t34;
}

export function _cart_total_effective(input) {
  let t61 = input["items"];
  let acc68 = 0.0;
  for (let items_i63 = 0; items_i63 < t61.length; items_i63++) {
    let items_el62 = t61[items_i63];
    let t64 = items_el62["price"];
    let t65 = 100.0;
    let t42 = t64 > t65;
    let t66 = items_el62["qty"];
    let t49 = t64 * t66;
    let t67 = 0.9;
    let t52 = t49 * t67;
    let t60 = t42 ? t52 : t49;
    acc68 += t60;
  }
  let t36 = acc68;
  return t36;
}

