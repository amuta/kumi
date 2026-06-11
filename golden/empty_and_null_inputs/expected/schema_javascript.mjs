export function _regional_sales(input) {
  let t7 = input["regions"];
  let arr15 = [];
  for (let regions_i9 = 0; regions_i9 < t7.length; regions_i9++) {
    let regions_el8 = t7[regions_i9];
    let t10 = regions_el8["sales"];
    let acc14 = 0;
    for (let sales_i12 = 0; sales_i12 < t10.length; sales_i12++) {
      let sales_el11 = t10[sales_i12];
      let t13 = sales_el11["amount"];
      acc14 += t13;
    }
    let t6 = acc14;
    arr15.push(t6);
  }
  return arr15;
}

export function _total_sales(input) {
  let t15 = input["regions"];
  let acc23 = 0;
  for (let regions_i17 = 0; regions_i17 < t15.length; regions_i17++) {
    let regions_el16 = t15[regions_i17];
    let t18 = regions_el16["sales"];
    let acc22 = 0;
    for (let sales_i20 = 0; sales_i20 < t18.length; sales_i20++) {
      let sales_el19 = t18[sales_i20];
      let t21 = sales_el19["amount"];
      acc22 += t21;
    }
    let t14 = acc22;
    acc23 += t14;
  }
  let t8 = acc23;
  return t8;
}

export function _adjusted_total(input) {
  let t19 = input["regions"];
  let acc27 = 0;
  for (let regions_i21 = 0; regions_i21 < t19.length; regions_i21++) {
    let regions_el20 = t19[regions_i21];
    let t22 = regions_el20["sales"];
    let acc26 = 0;
    for (let sales_i24 = 0; sales_i24 < t22.length; sales_i24++) {
      let sales_el23 = t22[sales_i24];
      let t25 = sales_el23["amount"];
      acc26 += t25;
    }
    let t17 = acc26;
    acc27 += t17;
  }
  let t18 = acc27;
  let t28 = input["adjustment"];
  let t11 = t18 + t28;
  return t11;
}

