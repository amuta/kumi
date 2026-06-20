export function _x_is_large(input) {
  let t7 = input["points"];
  let arr12 = [];
  for (let points_i9 = 0; points_i9 < t7.length; points_i9++) {
    let points_el8 = t7[points_i9];
    let t10 = points_el8["x"];
    let t11 = 100;
    let t6 = t10 > t11;
    arr12.push(t6);
  }
  return arr12;
}

export function _selected_value(input) {
  let t21 = input["points"];
  let arr27 = [];
  for (let points_i23 = 0; points_i23 < t21.length; points_i23++) {
    let points_el22 = t21[points_i23];
    let t24 = points_el22["x"];
    let t25 = 100;
    let t20 = t24 > t25;
    let t26 = points_el22["y"];
    let t14 = t20 ? t24 : t26;
    arr27.push(t14);
  }
  return arr27;
}

export function _final_value_per_point(input) {
  let t34 = input["points"];
  let arr40 = [];
  for (let points_i36 = 0; points_i36 < t34.length; points_i36++) {
    let points_el35 = t34[points_i36];
    let t37 = points_el35["x"];
    let t38 = 100;
    let t26 = t37 > t38;
    let t39 = points_el35["y"];
    let t33 = t26 ? t37 : t39;
    let acc0 = Math.max(t33, t37);
    arr40.push(acc0);
  }
  return arr40;
}

export function _grand_total(input) {
  let t36 = input["points"];
  let acc42 = 0;
  for (let points_i38 = 0; points_i38 < t36.length; points_i38++) {
    let points_el37 = t36[points_i38];
    let t39 = points_el37["x"];
    let t40 = 100;
    let t28 = t39 > t40;
    let t41 = points_el37["y"];
    let t35 = t28 ? t39 : t41;
    let acc0 = Math.max(t35, t39);
    acc42 += acc0;
  }
  return acc42;
}

