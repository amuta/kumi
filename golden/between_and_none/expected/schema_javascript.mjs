export function _in_range(input) {
  let t1 = input["x"];
  let t4 = t1 >= 1 && t1 <= 10;
  return t4;
}

export function _at_lower(input) {
  let t5 = input["x"];
  let t8 = t5 >= 5 && t5 <= 5;
  return t8;
}

export function _any_flag(input) {
  let acc_9 = null;
  let t10 = input["flags"];
  t10.forEach((flags_el_11, flags_i_12) => {
    let t13 = flags_el_11["active"];
    acc_9 = acc_9 || t13;
  });
  return acc_9;
}

export function _no_flags(input) {
  let acc_15 = null;
  let t16 = input["flags"];
  t16.forEach((flags_el_17, flags_i_18) => {
    let t19 = flags_el_17["active"];
    acc_15 = acc_15 || t19;
  });
  let t20 = !acc_15;
  return t20;
}

