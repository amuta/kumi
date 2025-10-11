export function _shift_right_zero(input) {
  let out = [];
  let t1 = input["cells"];
  let t4 = t1.length;
  const t5 = 1;
  const t7 = 0;
  let t12 = t4 - t5;
  t1.forEach((cells_el_2, cells_i_3) => {
    let t6 = cells_i_3 - t5;
    let t8 = t6 >= t7;
    let t9 = t6 < t4;
    let t14 = Math.min(Math.max(t6, t7), t12);
    let t10 = t8 && t9;
    let t15 = t1[t14];
    let t17 = t10 ? t15 : t7;
    out.push(t17);
  });
  return out;
}

export function _shift_left_zero(input) {
  let out = [];
  let t18 = input["cells"];
  let t21 = t18.length;
  const t22 = -1;
  const t24 = 0;
  const t28 = 1;
  let t29 = t21 - t28;
  t18.forEach((cells_el_19, cells_i_20) => {
    let t23 = cells_i_20 - t22;
    let t25 = t23 >= t24;
    let t26 = t23 < t21;
    let t31 = Math.min(Math.max(t23, t24), t29);
    let t27 = t25 && t26;
    let t32 = t18[t31];
    let t34 = t27 ? t32 : t24;
    out.push(t34);
  });
  return out;
}

export function _shift_right_clamp(input) {
  let out = [];
  let t35 = input["cells"];
  let t38 = t35.length;
  const t39 = 1;
  const t43 = 0;
  let t42 = t38 - t39;
  t35.forEach((cells_el_36, cells_i_37) => {
    let t40 = cells_i_37 - t39;
    let t44 = Math.min(Math.max(t40, t43), t42);
    let t45 = t35[t44];
    out.push(t45);
  });
  return out;
}

export function _shift_left_clamp(input) {
  let out = [];
  let t46 = input["cells"];
  let t49 = t46.length;
  const t50 = -1;
  const t52 = 1;
  const t54 = 0;
  let t53 = t49 - t52;
  t46.forEach((cells_el_47, cells_i_48) => {
    let t51 = cells_i_48 - t50;
    let t55 = Math.min(Math.max(t51, t54), t53);
    let t56 = t46[t55];
    out.push(t56);
  });
  return out;
}

export function _shift_right_wrap(input) {
  let out = [];
  let t57 = input["cells"];
  let t60 = t57.length;
  const t61 = 1;
  t57.forEach((cells_el_58, cells_i_59) => {
    let t62 = cells_i_59 - t61;
    let t63 = ((t62 % t60) + t60) % t60;
    let t64 = t63 + t60;
    let t65 = ((t64 % t60) + t60) % t60;
    let t66 = t57[t65];
    out.push(t66);
  });
  return out;
}

export function _shift_left_wrap(input) {
  let out = [];
  let t67 = input["cells"];
  let t70 = t67.length;
  const t71 = -1;
  t67.forEach((cells_el_68, cells_i_69) => {
    let t72 = cells_i_69 - t71;
    let t73 = ((t72 % t70) + t70) % t70;
    let t74 = t73 + t70;
    let t75 = ((t74 % t70) + t70) % t70;
    let t76 = t67[t75];
    out.push(t76);
  });
  return out;
}

