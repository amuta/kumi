export function _y_positive(input) {
  let t1 = input["y"];
  let t3 = t1 > 0;
  return t3;
}

export function _x_positive(input) {
  let t4 = input["x"];
  let t6 = t4 > 0;
  return t6;
}

export function _status(input) {
  let t19 = input["y"];
  let t21 = t19 > 0;
  let t22 = input["x"];
  let t24 = t22 > 0;
  let t9 = t21 && t24;
  let t16 = t21 ? "y positive" : "neither positive";
  let t17 = t24 ? "x positive" : t16;
  let t18 = t9 ? "both positive" : t17;
  return t18;
}

