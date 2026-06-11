export function _W(input) {
  let t4 = input["x"];
  let arr7 = [];
  for (let x_i6 = 0; x_i6 < t4.length; x_i6++) {
    let x_el5 = t4[x_i6];
    let t3 = x_el5.length;
    arr7.push(t3);
  }
  return arr7;
}

export function _box(input) {
  let t13 = input["x"];
  let arr18 = [];
  for (let x_i15 = 0; x_i15 < t13.length; x_i15++) {
    let x_el14 = t13[x_i15];
    let t12 = x_el14.length;
    let t6 = x_i15 * t12;
    let arr19 = [];
    for (let y_i17 = 0; y_i17 < x_el14.length; y_i17++) {
      let y_el16 = x_el14[y_i17];
      let t9 = t6 + y_i17;
      arr19.push(t9);
    }
    arr18.push(arr19);
  }
  return arr18;
}

export function _col_major(input) {
  let t18 = input["x"];
  let t12 = t18.length;
  let arr23 = [];
  for (let x_i20 = 0; x_i20 < t18.length; x_i20++) {
    let x_el19 = t18[x_i20];
    let arr24 = [];
    for (let y_i22 = 0; y_i22 < x_el19.length; y_i22++) {
      let y_el21 = x_el19[y_i22];
      let t14 = y_i22 * t12;
      let t17 = t14 + x_i20;
      arr24.push(t17);
    }
    arr23.push(arr24);
  }
  return arr23;
}

export function _sum_ij(input) {
  let t22 = input["x"];
  let arr27 = [];
  for (let x_i24 = 0; x_i24 < t22.length; x_i24++) {
    let x_el23 = t22[x_i24];
    let arr28 = [];
    for (let y_i26 = 0; y_i26 < x_el23.length; y_i26++) {
      let y_el25 = x_el23[y_i26];
      let t21 = x_i24 + y_i26;
      arr28.push(t21);
    }
    arr27.push(arr28);
  }
  return arr27;
}

