export function _times_one(input) {
  let t7 = input["items"];
  let arr12 = [];
  for (let items_i9 = 0; items_i9 < t7.length; items_i9++) {
    let items_el8 = t7[items_i9];
    let t10 = items_el8["price"];
    let t11 = 1.0;
    let t6 = t10 * t11;
    arr12.push(t6);
  }
  return arr12;
}

export function _div_one(input) {
  let t13 = input["items"];
  let arr18 = [];
  for (let items_i15 = 0; items_i15 < t13.length; items_i15++) {
    let items_el14 = t13[items_i15];
    let t16 = items_el14["price"];
    let t17 = 1.0;
    let t12 = t16 / t17;
    arr18.push(t12);
  }
  return arr18;
}

export function _sub_zero(input) {
  let t19 = input["items"];
  let arr24 = [];
  for (let items_i21 = 0; items_i21 < t19.length; items_i21++) {
    let items_el20 = t19[items_i21];
    let t22 = items_el20["price"];
    let t23 = 0.0;
    let t18 = t22 - t23;
    arr24.push(t18);
  }
  return arr24;
}

export function _plus_zero(input) {
  let t25 = input["items"];
  let arr30 = [];
  for (let items_i27 = 0; items_i27 < t25.length; items_i27++) {
    let items_el26 = t25[items_i27];
    let t28 = items_el26["qty"];
    let t29 = 0;
    let t24 = t28 + t29;
    arr30.push(t24);
  }
  return arr30;
}

export function _mul_zero(input) {
  let t31 = input["items"];
  let arr36 = [];
  for (let items_i33 = 0; items_i33 < t31.length; items_i33++) {
    let items_el32 = t31[items_i33];
    let t34 = items_el32["qty"];
    let t35 = 0;
    let t30 = t34 * t35;
    arr36.push(t30);
  }
  return arr36;
}

export function _price_check(input) {
  let t40 = input["items"];
  let acc44 = 0.0;
  for (let items_i42 = 0; items_i42 < t40.length; items_i42++) {
    let items_el41 = t40[items_i42];
    let t43 = items_el41["price"];
    let t33 = t43 + t43;
    let t35 = t33 - t43;
    acc44 += t35;
  }
  return acc44;
}

export function _qty_check(input) {
  let t44 = input["items"];
  let acc48 = 0;
  for (let items_i46 = 0; items_i46 < t44.length; items_i46++) {
    let items_el45 = t44[items_i46];
    let t47 = items_el45["qty"];
    acc48 += t47;
  }
  return acc48;
}

