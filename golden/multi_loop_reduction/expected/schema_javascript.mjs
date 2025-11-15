export function _total_value(input) {
  let acc_1 = 0;
  let t2 = input["items"];
  t2.forEach((items_el_3, items_i_4) => {
    let t5 = items_el_3["value"];
    acc_1 += t5;
  });
  return acc_1;
}

export function _half_total(input) {
  let acc22 = 0;
  let t23 = input["items"];
  t23.forEach((t24, t25) => {
    let t26 = t24["value"];
    acc22 += t26;
  });
  let t9 = acc22 * 0.5;
  return t9;
}

export function _high_value_sum(input) {
  let acc_10 = 0;
  let t11 = input["items"];
  let acc32 = 0;
  t11.forEach((t34, t35) => {
    let t36 = t34["value"];
    acc32 += t36;
  });
  let t30 = acc32 * 0.5;
  t11.forEach((items_el_12, items_i_13) => {
    let t14 = items_el_12["value"];
    let t16 = t14 > t30;
    let t19 = t16 ? t14 : 0;
    acc_10 += t19;
  });
  return acc_10;
}

