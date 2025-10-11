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
    t22.forEach((sales_el_6, sales_i_7) => {
      let t23 = sales_el_6["amount"];
      acc21 += t23;
    });
    acc_10 += acc21;
  });
  return acc_10;
}

export function _adjusted_total(input) {
  let acc26 = 0;
  let t27 = input["regions"];
  t27.forEach((regions_el_12, regions_i_13) => {
    let acc32 = 0;
    let t33 = regions_el_12["sales"];
    t33.forEach((sales_el_6, sales_i_7) => {
      let t34 = sales_el_6["amount"];
      acc32 += t34;
    });
    acc26 += acc32;
  });
  let t17 = input["adjustment"];
  let t18 = acc26 + t17;
  return t18;
}

