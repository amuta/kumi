export function _total_value(input) {
  let t5 = input["items"];
  let acc9 = 0;
  for (let items_i7 = 0; items_i7 < t5.length; items_i7++) {
    let items_el6 = t5[items_i7];
    let t8 = items_el6["value"];
    acc9 += t8;
  }
  let t4 = acc9;
  return t4;
}

export function _half_total(input) {
  let t12 = input["items"];
  let acc16 = 0;
  for (let items_i14 = 0; items_i14 < t12.length; items_i14++) {
    let items_el13 = t12[items_i14];
    let t15 = items_el13["value"];
    acc16 += t15;
  }
  let t11 = acc16;
  let t17 = 0.5;
  let t7 = t11 * t17;
  return t7;
}

export function _high_value_sum(input) {
  let t27 = input["items"];
  let acc31 = 0;
  for (let items_i29 = 0; items_i29 < t27.length; items_i29++) {
    let items_el28 = t27[items_i29];
    let t30 = items_el28["value"];
    acc31 += t30;
  }
  let t24 = acc31;
  let t32 = 0.5;
  let t26 = t24 * t32;
  let acc37 = 0;
  for (let items_i34 = 0; items_i34 < t27.length; items_i34++) {
    let items_el33 = t27[items_i34];
    let t35 = items_el33["value"];
    let t13 = t35 > t26;
    let t36 = 0;
    let t19 = t13 ? t35 : t36;
    acc37 += t19;
  }
  let t20 = acc37;
  return t20;
}

