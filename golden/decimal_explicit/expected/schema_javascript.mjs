export function _price(input) {
  let t3 = input["unit_price"];
  let t2 = typeof t3 === 'string' ? parseFloat(t3) : Number(t3);
  return t2;
}

export function _rate(input) {
  let t5 = input["tax_rate"];
  let t4 = typeof t5 === 'string' ? parseFloat(t5) : Number(t5);
  return t4;
}

export function _subtotal(input) {
  let t10 = input["unit_price"];
  let t9 = typeof t10 === 'string' ? parseFloat(t10) : Number(t10);
  let t11 = input["quantity"];
  let t7 = t9 * t11;
  return t7;
}

export function _tax_amount(input) {
  let t17 = input["unit_price"];
  let t12 = typeof t17 === 'string' ? parseFloat(t17) : Number(t17);
  let t18 = input["quantity"];
  let t14 = t12 * t18;
  let t19 = input["tax_rate"];
  let t16 = typeof t19 === 'string' ? parseFloat(t19) : Number(t19);
  let t10 = t14 * t16;
  return t10;
}

export function _total(input) {
  let t25 = input["unit_price"];
  let t15 = typeof t25 === 'string' ? parseFloat(t25) : Number(t25);
  let t26 = input["quantity"];
  let t17 = t15 * t26;
  let t27 = input["tax_rate"];
  let t23 = typeof t27 === 'string' ? parseFloat(t27) : Number(t27);
  let t24 = t17 * t23;
  let t13 = t17 + t24;
  return t13;
}

