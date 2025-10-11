export function _x_is_large(input) {
  let out = [];
  let t1 = input["points"];
  const t5 = 100;
  t1.forEach((points_el_2, points_i_3) => {
    let t4 = points_el_2["x"];
    let t6 = t4 > t5;
    out.push(t6);
  });
  return out;
}

export function _selected_value(input) {
  let out = [];
  let t7 = input["points"];
  const t29 = 100;
  t7.forEach((points_el_8, points_i_9) => {
    let t28 = points_el_8["x"];
    let t12 = points_el_8["y"];
    let t30 = t28 > t29;
    let t13 = t30 ? t28 : t12;
    out.push(t13);
  });
  return out;
}

export function _final_value_per_point(input) {
  let out = [];
  let t14 = input["points"];
  const t43 = 100;
  t14.forEach((points_el_15, points_i_16) => {
    let t42 = points_el_15["x"];
    let t34 = points_el_15["y"];
    let t44 = t42 > t43;
    let t35 = t44 ? t42 : t34;
    let t19 = [t35, t42];
    let t20 = Math.max(...t19);
    out.push(t20);
  });
  return out;
}

export function _grand_total(input) {
  let acc_21 = 0;
  let t22 = input["points"];
  const t48 = 100;
  t22.forEach((points_el_23, points_i_24) => {
    let t47 = points_el_23["x"];
    let t51 = points_el_23["y"];
    let t49 = t47 > t48;
    let t52 = t49 ? t47 : t51;
    let t39 = [t52, t47];
    let t40 = Math.max(...t39);
    acc_21 += t40;
  });
  return acc_21;
}

