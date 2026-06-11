export function _y_positive(input) {
  let t4 = input["y"];
  let t5 = 0;
  let t3 = t4 > t5;
  return t3;
}

export function _x_positive(input) {
  let t7 = input["x"];
  let t8 = 0;
  let t6 = t7 > t8;
  return t6;
}

export function _status(input) {
  let t25 = input["y"];
  let t26 = 0;
  let t21 = t25 > t26;
  let t27 = input["x"];
  let t24 = t27 > t26;
  let t9 = t21 && t24;
  let t28 = "y positive";
  let t29 = "neither positive";
  let t16 = t21 ? t28 : t29;
  let t30 = "x positive";
  let t17 = t24 ? t30 : t16;
  let t31 = "both positive";
  let t18 = t9 ? t31 : t17;
  return t18;
}

