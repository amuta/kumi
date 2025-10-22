export function _order_subtotal(input) {
  let t1 = input["order_items"];
  let t2 = GoldenSchemas.Subtotal.from({'items': t1})._subtotal;
  return t2;
}

export function _tax_amount(input) {
  let t9 = input["order_items"];
  let t10 = GoldenSchemas.Subtotal.from({'items': t9})._subtotal;
  let t4 = input["tax_rate"];
  let t5 = t10 * t4;
  return t5;
}

export function _total(input) {
  let t11 = input["order_items"];
  let t12 = GoldenSchemas.Subtotal.from({'items': t11})._subtotal;
  let t14 = input["tax_rate"];
  let t15 = t12 * t14;
  let t8 = t12 + t15;
  return t8;
}

