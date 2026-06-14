export function _e(input) {
  let t5 = input["xs"];
  let arr9 = [];
  for (let xs_i7 = 0; xs_i7 < t5.length; xs_i7++) {
    let xs_el6 = t5[xs_i7];
    let t8 = xs_el6["v"];
    let t4 = Math.exp(t8);
    arr9.push(t4);
  }
  return arr9;
}

export function _l(input) {
  let t9 = input["xs"];
  let arr13 = [];
  for (let xs_i11 = 0; xs_i11 < t9.length; xs_i11++) {
    let xs_el10 = t9[xs_i11];
    let t12 = xs_el10["v"];
    let t8 = Math.log(t12);
    arr13.push(t8);
  }
  return arr13;
}

export function _t(input) {
  let t13 = input["xs"];
  let arr17 = [];
  for (let xs_i15 = 0; xs_i15 < t13.length; xs_i15++) {
    let xs_el14 = t13[xs_i15];
    let t16 = xs_el14["v"];
    let t12 = Math.tanh(t16);
    arr17.push(t12);
  }
  return arr17;
}

export function _neg(input) {
  let t19 = input["xs"];
  let arr24 = [];
  for (let xs_i21 = 0; xs_i21 < t19.length; xs_i21++) {
    let xs_el20 = t19[xs_i21];
    let t22 = 0.0;
    let t23 = xs_el20["v"];
    let t18 = t22 - t23;
    arr24.push(t18);
  }
  return arr24;
}

export function _sigmoid(input) {
  let t33 = input["xs"];
  let arr39 = [];
  for (let xs_i35 = 0; xs_i35 < t33.length; xs_i35++) {
    let xs_el34 = t33[xs_i35];
    let t36 = 0.0;
    let t37 = xs_el34["v"];
    let t32 = t36 - t37;
    let t24 = Math.exp(t32);
    let t38 = 1.0;
    let t25 = t38 + t24;
    let t26 = t38 / t25;
    arr39.push(t26);
  }
  return arr39;
}

