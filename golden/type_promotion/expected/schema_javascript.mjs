export function _price(input) {
  let t3 = input["price_text"];
  let t2 = typeof t3 === 'string' ? parseFloat(t3) : Number(t3);
  return t2;
}

export function _rate(input) {
  let t5 = input["rate_text"];
  let t4 = typeof t5 === 'string' ? parseFloat(t5) : Number(t5);
  return t4;
}

export function _int_times_float(input) {
  let t8 = input["count"];
  let t9 = input["weight"];
  let t7 = t8 * t9;
  return t7;
}

export function _decimal_times_int(input) {
  let t13 = input["price_text"];
  let t12 = typeof t13 === 'string' ? parseFloat(t13) : Number(t13);
  let t14 = input["count"];
  let t10 = t12 * t14;
  return t10;
}

export function _decimal_plus_float(input) {
  let t16 = input["price_text"];
  let t15 = typeof t16 === 'string' ? parseFloat(t16) : Number(t16);
  let t17 = input["weight"];
  let t13 = t15 + t17;
  return t13;
}

export function _float_plus_int(input) {
  let t17 = input["weight"];
  let t18 = input["count"];
  let t16 = t17 + t18;
  return t16;
}

export function _amount_values(input) {
  let t21 = input["amounts"];
  let arr25 = [];
  for (let amounts_i23 = 0; amounts_i23 < t21.length; amounts_i23++) {
    let amounts_el22 = t21[amounts_i23];
    let t24 = amounts_el22["value"];
    let t20 = typeof t24 === 'string' ? parseFloat(t24) : Number(t24);
    arr25.push(t20);
  }
  return arr25;
}

export function _scaled_amounts(input) {
  let t31 = input["amounts"];
  let t35 = input["rate_text"];
  let t30 = typeof t35 === 'string' ? parseFloat(t35) : Number(t35);
  let arr40 = [];
  for (let amounts_i33 = 0; amounts_i33 < t31.length; amounts_i33++) {
    let amounts_el32 = t31[amounts_i33];
    let t34 = amounts_el32["value"];
    let t28 = typeof t34 === 'string' ? parseFloat(t34) : Number(t34);
    let t24 = t28 * t30;
    arr40.push(t24);
  }
  return arr40;
}

export function _total_scaled(input) {
  let t35 = input["amounts"];
  let t39 = input["rate_text"];
  let t32 = typeof t39 === 'string' ? parseFloat(t39) : Number(t39);
  let acc44 = 0;
  for (let amounts_i37 = 0; amounts_i37 < t35.length; amounts_i37++) {
    let amounts_el36 = t35[amounts_i37];
    let t38 = amounts_el36["value"];
    let t30 = typeof t38 === 'string' ? parseFloat(t38) : Number(t38);
    let t34 = t30 * t32;
    acc44 += t34;
  }
  return acc44;
}

export function _amount_count(input) {
  let t29 = input["amounts"];
  let t28 = t29.length;
  return t28;
}

