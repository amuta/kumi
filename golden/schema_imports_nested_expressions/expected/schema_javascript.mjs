export function _interest(input) {
  let t7 = input["amount"];
  let t8 = 1.05;
  let t3 = t7 * t8;
  let t9 = input["rate"];
  let t6 = t3 * t9;
  return t6;
}

export function _total_over_periods(input) {
  let t15 = input["amount"];
  let t16 = 1.05;
  let t11 = t15 * t16;
  let t17 = input["rate"];
  let t14 = t11 * t17;
  let t18 = input["periods"];
  let t8 = t14 * t18;
  return t8;
}

export function _doubled(input) {
  let t20 = input["amount"];
  let t21 = 1.05;
  let t14 = t20 * t21;
  let t22 = input["rate"];
  let t19 = t14 * t22;
  let t23 = input["periods"];
  let t18 = t19 * t23;
  let t24 = 2;
  let t11 = t18 * t24;
  return t11;
}

