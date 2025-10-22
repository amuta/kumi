export function _interest(input) {
  let t1 = input["amount"];
  const t2 = 1.05;
  let t3 = t1 * t2;
  let t4 = input["rate"];
  let t5 = GoldenSchemas.Compound.from({'principal': t3, 'rate': t4})._annual_interest;
  return t5;
}

export function _total_over_periods(input) {
  let t12 = input["amount"];
  const t13 = 1.05;
  let t14 = t12 * t13;
  let t15 = input["rate"];
  let t16 = GoldenSchemas.Compound.from({'principal': t14, 'rate': t15})._annual_interest;
  let t7 = input["periods"];
  let t8 = t16 * t7;
  return t8;
}

export function _doubled(input) {
  let t20 = input["amount"];
  const t21 = 1.05;
  let t22 = t20 * t21;
  let t23 = input["rate"];
  let t24 = GoldenSchemas.Compound.from({'principal': t22, 'rate': t23})._annual_interest;
  let t18 = input["periods"];
  let t19 = t24 * t18;
  const t10 = 2;
  let t11 = t19 * t10;
  return t11;
}

