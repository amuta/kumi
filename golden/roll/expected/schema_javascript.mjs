export function _roll_right(input) {
  let t4 = input["cells"];
  let arr10 = [];
  for (let cells_i6 = 0; cells_i6 < t4.length; cells_i6++) {
    let cells_el5 = t4[cells_i6];
    let t7 = input["cells"];
    let t8 = t7.length;
    let t9 = t7[(((cells_i6 - (1)) % t8) + t8) % t8];
    let t1 = t9;
    arr10.push(t1);
  }
  return arr10;
}

export function _roll_left(input) {
  let t7 = input["cells"];
  let arr13 = [];
  for (let cells_i9 = 0; cells_i9 < t7.length; cells_i9++) {
    let cells_el8 = t7[cells_i9];
    let t10 = input["cells"];
    let t11 = t10.length;
    let t12 = t10[(((cells_i9 - (-1)) % t11) + t11) % t11];
    let t4 = t12;
    arr13.push(t4);
  }
  return arr13;
}

export function _roll_right_clamp(input) {
  let t10 = input["cells"];
  let arr16 = [];
  for (let cells_i12 = 0; cells_i12 < t10.length; cells_i12++) {
    let cells_el11 = t10[cells_i12];
    let t13 = input["cells"];
    let t14 = t13.length;
    let t15 = t13[Math.min(Math.max(cells_i12 - (1), 0), t14 - 1)];
    let t7 = t15;
    arr16.push(t7);
  }
  return arr16;
}

export function _roll_left_clamp(input) {
  let t13 = input["cells"];
  let arr19 = [];
  for (let cells_i15 = 0; cells_i15 < t13.length; cells_i15++) {
    let cells_el14 = t13[cells_i15];
    let t16 = input["cells"];
    let t17 = t16.length;
    let t18 = t16[Math.min(Math.max(cells_i15 - (-1), 0), t17 - 1)];
    let t10 = t18;
    arr19.push(t10);
  }
  return arr19;
}

