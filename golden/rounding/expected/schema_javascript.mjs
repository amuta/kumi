export function _rounded_0(input) {
  let t1 = input["x"];
  let t3 = Number(t1.toFixed(0));
  return t3;
}

export function _rounded_2(input) {
  let t4 = input["x"];
  let t6 = Number(t4.toFixed(2));
  return t6;
}

export function _rounded_y(input) {
  let t7 = input["y"];
  let t9 = Number(t7.toFixed(1));
  return t9;
}

export function _floored(input) {
  let t10 = input["x"];
  let t11 = Math.floor(t10);
  return t11;
}

export function _ceiled(input) {
  let t12 = input["x"];
  let t13 = Math.ceil(t12);
  return t13;
}

export function _floor_neg(input) {
  let t14 = input["y"];
  let t15 = Math.floor(t14);
  return t15;
}

export function _ceil_neg(input) {
  let t16 = input["y"];
  let t17 = Math.ceil(t16);
  return t17;
}

