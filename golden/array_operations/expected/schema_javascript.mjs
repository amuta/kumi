export function _subtotals(input) {
  let t8 = input["items"];
  let arr13 = [];
  for (let items_i10 = 0; items_i10 < t8.length; items_i10++) {
    let items_el9 = t8[items_i10];
    let t11 = items_el9["price"];
    let t12 = items_el9["quantity"];
    let t7 = t11 * t12;
    arr13.push(t7);
  }
  return arr13;
}

export function _discounted_price(input) {
  let t14 = input["items"];
  let arr19 = [];
  for (let items_i16 = 0; items_i16 < t14.length; items_i16++) {
    let items_el15 = t14[items_i16];
    let t17 = items_el15["price"];
    let t18 = 0.9;
    let t13 = t17 * t18;
    arr19.push(t13);
  }
  return arr19;
}

export function _is_valid_quantity(input) {
  let t20 = input["items"];
  let arr25 = [];
  for (let items_i22 = 0; items_i22 < t20.length; items_i22++) {
    let items_el21 = t20[items_i22];
    let t23 = items_el21["quantity"];
    let t24 = 0;
    let t19 = t23 > t24;
    arr25.push(t19);
  }
  return arr25;
}

export function _expensive_items(input) {
  let t26 = input["items"];
  let arr31 = [];
  for (let items_i28 = 0; items_i28 < t26.length; items_i28++) {
    let items_el27 = t26[items_i28];
    let t29 = items_el27["price"];
    let t30 = 100.0;
    let t25 = t29 > t30;
    arr31.push(t25);
  }
  return arr31;
}

export function _electronics(input) {
  let t32 = input["items"];
  let arr37 = [];
  for (let items_i34 = 0; items_i34 < t32.length; items_i34++) {
    let items_el33 = t32[items_i34];
    let t35 = items_el33["category"];
    let t36 = "electronics";
    let t31 = t35 == t36;
    arr37.push(t31);
  }
  return arr37;
}

