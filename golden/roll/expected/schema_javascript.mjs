export function _roll_right(input) {
  let out = [];
  let t1 = input["cells"];
  let t4 = t1.length;
  t1.forEach((cells_el_2, cells_i_3) => {
    let t6 = cells_i_3 - 1;
    let t7 = ((t6 % t4) + t4) % t4;
    let t8 = t7 + t4;
    let t9 = ((t8 % t4) + t4) % t4;
    let t10 = t1[t9];
    out.push(t10);
  });
  return out;
}

export function _roll_left(input) {
  let out = [];
  let t11 = input["cells"];
  let t14 = t11.length;
  t11.forEach((cells_el_12, cells_i_13) => {
    let t16 = cells_i_13 - -1;
    let t17 = ((t16 % t14) + t14) % t14;
    let t18 = t17 + t14;
    let t19 = ((t18 % t14) + t14) % t14;
    let t20 = t11[t19];
    out.push(t20);
  });
  return out;
}

export function _roll_right_clamp(input) {
  let out = [];
  let t21 = input["cells"];
  let t24 = t21.length;
  let t28 = t24 - 1;
  t21.forEach((cells_el_22, cells_i_23) => {
    let t26 = cells_i_23 - 1;
    let t30 = Math.min(Math.max(t26, 0), t28);
    let t31 = t21[t30];
    out.push(t31);
  });
  return out;
}

export function _roll_left_clamp(input) {
  let out = [];
  let t32 = input["cells"];
  let t35 = t32.length;
  let t39 = t35 - 1;
  t32.forEach((cells_el_33, cells_i_34) => {
    let t37 = cells_i_34 - -1;
    let t41 = Math.min(Math.max(t37, 0), t39);
    let t42 = t32[t41];
    out.push(t42);
  });
  return out;
}

