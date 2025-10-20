export function _subtotal(input) {
  let t14 = input["unit_price"];
  let t15 = typeof t14 === 'string' ? parseFloat(t14) : Number(t14);
  let t6 = input["quantity"];
  let t7 = t15 * t6;
  return t7;
}

export function _tax_amount(input) {
  let t19 = input["unit_price"];
  let t20 = typeof t19 === 'string' ? parseFloat(t19) : Number(t19);
  let t17 = input["quantity"];
  let t18 = t20 * t17;
  let t21 = input["tax_rate"];
  let t22 = typeof t21 === 'string' ? parseFloat(t21) : Number(t21);
  let t10 = t18 * t22;
  return t10;
}

export function _total(input) {
  let t26 = input["unit_price"];
  let t27 = typeof t26 === 'string' ? parseFloat(t26) : Number(t26);
  let t24 = input["quantity"];
  let t25 = t27 * t24;
  let t36 = input["tax_rate"];
  let t37 = typeof t36 === 'string' ? parseFloat(t36) : Number(t36);
  let t30 = t25 * t37;
  let t13 = t25 + t30;
  return t13;
}

