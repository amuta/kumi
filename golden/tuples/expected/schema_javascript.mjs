export function _tuple(input) {
  let t4 = input["x"];
  let t5 = [1, 2, 3, t4];
  return t5;
}

export function _max_1(input) {
  let t27 = input["x"];
  let t28 = [1, 2, 3, t27];
  let t7 = Math.max(...t28);
  return t7;
}

export function _max_2(input) {
  let t11 = input["x"];
  let t13 = [1, 2, 3, t11, 1000];
  let t14 = Math.max(...t13);
  return t14;
}

export function _min_1(input) {
  let t32 = input["x"];
  let t33 = [1, 2, 3, t32];
  let t16 = Math.min(...t33);
  return t16;
}

export function _min_2(input) {
  let t20 = input["x"];
  let t22 = [1, 2, 3, t20, -100];
  let t23 = Math.min(...t22);
  return t23;
}

