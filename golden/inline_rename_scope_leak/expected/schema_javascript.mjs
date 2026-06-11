export function _sum_x(input) {
  let t5 = input["xs"];
  let acc9 = 0.0;
  for (let xs_i7 = 0; xs_i7 < t5.length; xs_i7++) {
    let xs_el6 = t5[xs_i7];
    let t8 = xs_el6["v"];
    acc9 += t8;
  }
  let t4 = acc9;
  return t4;
}

export function _sum_y(input) {
  let t9 = input["ys"];
  let acc13 = 0.0;
  for (let ys_i11 = 0; ys_i11 < t9.length; ys_i11++) {
    let ys_el10 = t9[ys_i11];
    let t12 = ys_el10["v"];
    acc13 += t12;
  }
  let t8 = acc13;
  return t8;
}

export function _tail(input) {
  let t12 = 12.0;
  return t12;
}

export function _out(input) {
  let t27 = input["xs"];
  let acc31 = 0.0;
  for (let xs_i29 = 0; xs_i29 < t27.length; xs_i29++) {
    let xs_el28 = t27[xs_i29];
    let t30 = xs_el28["v"];
    acc31 += t30;
  }
  let t19 = acc31;
  let t32 = input["ys"];
  let acc36 = 0.0;
  for (let ys_i34 = 0; ys_i34 < t32.length; ys_i34++) {
    let ys_el33 = t32[ys_i34];
    let t35 = ys_el33["v"];
    acc36 += t35;
  }
  let t23 = acc36;
  let t37 = 12.0;
  let t15 = { "x": t19, "y": t23, "t": t37 };
  return t15;
}

