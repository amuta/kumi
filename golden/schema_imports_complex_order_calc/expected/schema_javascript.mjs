export function _order_subtotals(input) {
  let out = [];
  let t1 = input["orders"];
  t1.forEach((orders_el_2, orders_i_3) => {
    let t4 = orders_el_2["items"];
    let t5 = GoldenSchemas.Subtotal.from({'items': t4})._subtotal;
    out.push(t5);
  });
  return out;
}

export function _order_with_shipping(input) {
  let out = [];
  let t6 = input["orders"];
  t6.forEach((orders_el_7, orders_i_8) => {
    let t60 = orders_el_7["items"];
    let t10 = orders_el_7["shipping_cost"];
    let t61 = GoldenSchemas.Subtotal.from({'items': t60})._subtotal;
    let t11 = t61 + t10;
    out.push(t11);
  });
  return out;
}

export function _order_discounted(input) {
  let out = [];
  let t12 = input["orders"];
  let t16 = input["global_discount_rate"];
  t12.forEach((orders_el_13, orders_i_14) => {
    let t67 = orders_el_13["items"];
    let t64 = orders_el_13["shipping_cost"];
    let t68 = GoldenSchemas.Subtotal.from({'items': t67})._subtotal;
    let t65 = t68 + t64;
    let t17 = GoldenSchemas.Discount.from({'price': t65, 'rate': t16})._discounted;
    out.push(t17);
  });
  return out;
}

export function _order_tax(input) {
  let out = [];
  let t18 = input["orders"];
  let t71 = input["global_discount_rate"];
  t18.forEach((orders_el_19, orders_i_20) => {
    let t78 = orders_el_19["items"];
    let t75 = orders_el_19["shipping_cost"];
    let t79 = GoldenSchemas.Subtotal.from({'items': t78})._subtotal;
    let t76 = t79 + t75;
    let t72 = GoldenSchemas.Discount.from({'price': t76, 'rate': t71})._discounted;
    let t22 = GoldenSchemas.Tax.from({'amount': t72})._tax;
    out.push(t22);
  });
  return out;
}

export function _order_totals(input) {
  let out = [];
  let t23 = input["orders"];
  let t82 = input["global_discount_rate"];
  t23.forEach((orders_el_24, orders_i_25) => {
    let t89 = orders_el_24["items"];
    let t86 = orders_el_24["shipping_cost"];
    let t90 = GoldenSchemas.Subtotal.from({'items': t89})._subtotal;
    let t87 = t90 + t86;
    let t83 = GoldenSchemas.Discount.from({'price': t87, 'rate': t82})._discounted;
    let t93 = GoldenSchemas.Tax.from({'amount': t83})._tax;
    let t28 = t83 + t93;
    out.push(t28);
  });
  return out;
}

export function _discount_per_order(input) {
  let out = [];
  let t29 = input["orders"];
  let t114 = input["global_discount_rate"];
  t29.forEach((orders_el_30, orders_i_31) => {
    let t110 = orders_el_30["items"];
    let t107 = orders_el_30["shipping_cost"];
    let t111 = GoldenSchemas.Subtotal.from({'items': t110})._subtotal;
    let t108 = t111 + t107;
    let t115 = GoldenSchemas.Discount.from({'price': t108, 'rate': t114})._discounted;
    let t34 = t108 - t115;
    out.push(t34);
  });
  return out;
}

export function _total_orders(input) {
  let acc_35 = 0;
  let t36 = input["orders"];
  t36.forEach((orders_el_37, orders_i_38) => {
    let t39 = orders_el_37["id"];
    acc_35 += 1;
  });
  return acc_35;
}

export function _total_revenue(input) {
  let acc_41 = 0.0;
  let t42 = input["orders"];
  let t129 = input["global_discount_rate"];
  t42.forEach((orders_el_43, orders_i_44) => {
    let t136 = orders_el_43["items"];
    let t133 = orders_el_43["shipping_cost"];
    let t137 = GoldenSchemas.Subtotal.from({'items': t136})._subtotal;
    let t134 = t137 + t133;
    let t130 = GoldenSchemas.Discount.from({'price': t134, 'rate': t129})._discounted;
    let t140 = GoldenSchemas.Tax.from({'amount': t130})._tax;
    let t126 = t130 + t140;
    acc_41 += t126;
  });
  return acc_41;
}

export function _total_tax_collected(input) {
  let acc_47 = 0.0;
  let t48 = input["orders"];
  let t157 = input["global_discount_rate"];
  t48.forEach((orders_el_49, orders_i_50) => {
    let t164 = orders_el_49["items"];
    let t161 = orders_el_49["shipping_cost"];
    let t165 = GoldenSchemas.Subtotal.from({'items': t164})._subtotal;
    let t162 = t165 + t161;
    let t158 = GoldenSchemas.Discount.from({'price': t162, 'rate': t157})._discounted;
    let t154 = GoldenSchemas.Tax.from({'amount': t158})._tax;
    acc_47 += t154;
  });
  return acc_47;
}

export function _total_discount_given(input) {
  let acc_53 = 0.0;
  let t54 = input["orders"];
  let t179 = input["global_discount_rate"];
  t54.forEach((orders_el_55, orders_i_56) => {
    let t175 = orders_el_55["items"];
    let t172 = orders_el_55["shipping_cost"];
    let t176 = GoldenSchemas.Subtotal.from({'items': t175})._subtotal;
    let t173 = t176 + t172;
    let t180 = GoldenSchemas.Discount.from({'price': t173, 'rate': t179})._discounted;
    let t169 = t173 - t180;
    acc_53 += t169;
  });
  return acc_53;
}

