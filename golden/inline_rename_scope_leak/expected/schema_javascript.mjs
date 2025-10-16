export function _sum_x(input) {
  let acc_1 = 0.0;
  let t2 = input["xs"];
  t2.forEach((xs_el_3, xs_i_4) => {
    let t5 = xs_el_3["v"];
    acc_1 += t5;
  });
  return acc_1;
}

export function _sum_y(input) {
  let acc_7 = 0.0;
  let t8 = input["ys"];
  t8.forEach((ys_el_9, ys_i_10) => {
    let t11 = ys_el_9["v"];
    acc_7 += t11;
  });
  return acc_7;
}

export function _tail(input) {
  const t13 = 7.0;
  const t14 = 5.0;
  let t15 = t13 + t14;
  return t15;
}

export function _out(input) {
  let acc21 = 0.0;
  let t22 = input["xs"];
  t22.forEach((t23, t24) => {
    let t25 = t23["v"];
    acc21 += t25;
  });
  let acc28 = 0.0;
  let t29 = input["ys"];
  t29.forEach((t30, t31) => {
    let t32 = t30["v"];
    acc28 += t32;
  });
  const t34 = 7.0;
  const t35 = 5.0;
  let t36 = t34 + t35;
  let t19 = {
    "x": acc21,
    "y": acc28,
    "t": t36
  };
  return t19;
}

