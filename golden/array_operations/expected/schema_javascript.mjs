export function _subtotals(input) {
  let out = [];
  let t1 = input["items"];
  t1.forEach((items_el_2, items_i_3) => {
    let t4 = items_el_2["price"];
    let t5 = items_el_2["quantity"];
    let t6 = t4 * t5;
    out.push(t6);
  });
  return out;
}

export function _discounted_price(input) {
  let out = [];
  let t7 = input["items"];
  t7.forEach((items_el_8, items_i_9) => {
    let t10 = items_el_8["price"];
    let t12 = t10 * 0.9;
    out.push(t12);
  });
  return out;
}

export function _is_valid_quantity(input) {
  let out = [];
  let t13 = input["items"];
  t13.forEach((items_el_14, items_i_15) => {
    let t16 = items_el_14["quantity"];
    let t18 = t16 > 0;
    out.push(t18);
  });
  return out;
}

export function _expensive_items(input) {
  let out = [];
  let t19 = input["items"];
  t19.forEach((items_el_20, items_i_21) => {
    let t22 = items_el_20["price"];
    let t24 = t22 > 100.0;
    out.push(t24);
  });
  return out;
}

export function _electronics(input) {
  let out = [];
  let t25 = input["items"];
  t25.forEach((items_el_26, items_i_27) => {
    let t28 = items_el_26["category"];
    let t30 = t28 == "electronics";
    out.push(t30);
  });
  return out;
}

