export function _x_sq(input) {
  let t4 = input["x"];
  let t3 = t4 * t4;
  return t3;
}

export function _y_sq(input) {
  let t7 = input["y"];
  let t6 = t7 * t7;
  return t6;
}

export function _distance_sq(input) {
  let t16 = input["x"];
  let t12 = t16 * t16;
  let t17 = input["y"];
  let t15 = t17 * t17;
  let t9 = t12 + t15;
  return t9;
}

export function _distance(input) {
  let t20 = input["x"];
  let t15 = t20 * t20;
  let t21 = input["y"];
  let t18 = t21 * t21;
  let t19 = t15 + t18;
  let t22 = 0.5;
  let t12 = Math.pow(t19, t22);
  return t12;
}

