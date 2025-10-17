export function _regional_sales(input) {
  let out = [];
  let t1 = input["regions"];
  t1.forEach((regions_el_2, regions_i_3) => {
    let acc_4 = 0;
    let t5 = regions_el_2["sales"];
    t5.forEach((sales_el_6, sales_i_7) => {
      let t8 = sales_el_6["amount"];
      acc_4 += t8;
    });
    out.push(acc_4);
  });
  return out;
}

export function _total_sales(input) {
  let acc_10 = 0;
  let t11 = input["regions"];
  t11.forEach((regions_el_12, regions_i_13) => {
    let acc21 = 0;
    let t22 = regions_el_12["sales"];
    t22.forEach((t23, t24) => {
      let t25 = t23["amount"];
      acc21 += t25;
    });
    acc_10 += acc21;
  });
  return acc_10;
}

export function _adjusted_total(input) {
  let acc28 = 0;
  let t29 = input["regions"];
  t29.forEach((t30, t31) => {
    let acc36 = 0;
    let t37 = t30["sales"];
    t37.forEach((t38, t39) => {
      let t40 = t38["amount"];
      acc36 += t40;
    });
    acc28 += acc36;
  });
  let t17 = input["adjustment"];
  let t18 = acc28 + t17;
  return t18;
}

