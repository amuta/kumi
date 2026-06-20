export function _shift_right_zero(input) {
  let t4 = input["cells"];
  let arr12 = [];
  for (let cells_i6 = 0; cells_i6 < t4.length; cells_i6++) {
    let cells_el5 = t4[cells_i6];
    let t7 = input["cells"];
    let t8 = t7.length;
    let t9 = t7[Math.min(Math.max(cells_i6 - (1), 0), t8 - 1)];
    let t10_j = cells_i6 - (1);
    let t10 = t10_j >= 0 && t10_j < t8;
    let t11 = 0;
    let t1 = t10 ? t9 : t11;
    arr12.push(t1);
  }
  return arr12;
}

export function _shift_left_zero(input) {
  let t7 = input["cells"];
  let arr15 = [];
  for (let cells_i9 = 0; cells_i9 < t7.length; cells_i9++) {
    let cells_el8 = t7[cells_i9];
    let t10 = input["cells"];
    let t11 = t10.length;
    let t12 = t10[Math.min(Math.max(cells_i9 - (-1), 0), t11 - 1)];
    let t13_j = cells_i9 - (-1);
    let t13 = t13_j >= 0 && t13_j < t11;
    let t14 = 0;
    let t4 = t13 ? t12 : t14;
    arr15.push(t4);
  }
  return arr15;
}

export function _shift_right_clamp(input) {
  let t10 = input["cells"];
  let arr16 = [];
  for (let cells_i12 = 0; cells_i12 < t10.length; cells_i12++) {
    let cells_el11 = t10[cells_i12];
    let t13 = input["cells"];
    let t14 = t13.length;
    let t15 = t13[Math.min(Math.max(cells_i12 - (1), 0), t14 - 1)];
    arr16.push(t15);
  }
  return arr16;
}

export function _shift_left_clamp(input) {
  let t13 = input["cells"];
  let arr19 = [];
  for (let cells_i15 = 0; cells_i15 < t13.length; cells_i15++) {
    let cells_el14 = t13[cells_i15];
    let t16 = input["cells"];
    let t17 = t16.length;
    let t18 = t16[Math.min(Math.max(cells_i15 - (-1), 0), t17 - 1)];
    arr19.push(t18);
  }
  return arr19;
}

export function _shift_right_wrap(input) {
  let t16 = input["cells"];
  let arr22 = [];
  for (let cells_i18 = 0; cells_i18 < t16.length; cells_i18++) {
    let cells_el17 = t16[cells_i18];
    let t19 = input["cells"];
    let t20 = t19.length;
    let t21 = t19[(((cells_i18 - (1)) % t20) + t20) % t20];
    arr22.push(t21);
  }
  return arr22;
}

export function _shift_left_wrap(input) {
  let t19 = input["cells"];
  let arr25 = [];
  for (let cells_i21 = 0; cells_i21 < t19.length; cells_i21++) {
    let cells_el20 = t19[cells_i21];
    let t22 = input["cells"];
    let t23 = t22.length;
    let t24 = t22[(((cells_i21 - (-1)) % t23) + t23) % t23];
    arr25.push(t24);
  }
  return arr25;
}

