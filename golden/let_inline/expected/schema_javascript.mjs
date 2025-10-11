export function _distance(input) {
  let t22 = input["x"];
  let t24 = t22 * t22;
  let t25 = input["y"];
  let t27 = t25 * t25;
  let t21 = t24 + t27;
  const t11 = 0.5;
  let t12 = Math.pow(t21, t11);
  return t12;
}

