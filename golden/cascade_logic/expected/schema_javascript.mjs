export function _y_positive(input) {
  let t1 = input["y"];
  const t2 = 0;
  let t3 = t1 > t2;
  return t3;
}

export function _x_positive(input) {
  let t4 = input["x"];
  const t5 = 0;
  let t6 = t4 > t5;
  return t6;
}

export function _status(input) {
  let t19 = input["y"];
  const t20 = 0;
  let t21 = t19 > t20;
  let t22 = input["x"];
  let t24 = t22 > t20;
  let t9 = t21 && t24;
  const t10 = "both positive";
  const t12 = "x positive";
  const t14 = "y positive";
  const t15 = "neither positive";
  let t16 = t21 ? t14 : t15;
  let t17 = t24 ? t12 : t16;
  let t18 = t9 ? t10 : t17;
  return t18;
}

