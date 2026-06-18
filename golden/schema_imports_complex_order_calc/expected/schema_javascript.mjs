export function _order_subtotals(input) {
  let t10 = input["orders"];
  let arr19 = [];
  for (let orders_i12 = 0; orders_i12 < t10.length; orders_i12++) {
    let orders_el11 = t10[orders_i12];
    let t13 = orders_el11["items"];
    let acc18 = 0;
    for (let items_i15 = 0; items_i15 < t13.length; items_i15++) {
      let items_el14 = t13[items_i15];
      let t16 = items_el14["quantity"];
      let t17 = items_el14["unit_price"];
      let t8 = t16 * t17;
      acc18 += t8;
    }
    let t9 = acc18;
    arr19.push(t9);
  }
  return arr19;
}

export function _order_with_shipping(input) {
  let t19 = input["orders"];
  let arr29 = [];
  for (let orders_i21 = 0; orders_i21 < t19.length; orders_i21++) {
    let orders_el20 = t19[orders_i21];
    let t22 = orders_el20["items"];
    let acc27 = 0;
    for (let items_i24 = 0; items_i24 < t22.length; items_i24++) {
      let items_el23 = t22[items_i24];
      let t25 = items_el23["quantity"];
      let t26 = items_el23["unit_price"];
      let t17 = t25 * t26;
      acc27 += t17;
    }
    let t18 = acc27;
    let t28 = orders_el20["shipping_cost"];
    let t9 = t18 + t28;
    arr29.push(t9);
  }
  return arr29;
}

export function _order_discounted(input) {
  let t30 = input["orders"];
  let arr42 = [];
  for (let orders_i32 = 0; orders_i32 < t30.length; orders_i32++) {
    let orders_el31 = t30[orders_i32];
    let t33 = orders_el31["items"];
    let acc38 = 0;
    for (let items_i35 = 0; items_i35 < t33.length; items_i35++) {
      let items_el34 = t33[items_i35];
      let t36 = items_el34["quantity"];
      let t37 = items_el34["unit_price"];
      let t25 = t36 * t37;
      acc38 += t25;
    }
    let t26 = acc38;
    let t39 = orders_el31["shipping_cost"];
    let t21 = t26 + t39;
    let t40 = 1.0;
    let t41 = input["global_discount_rate"];
    let t28 = t40 - t41;
    let t29 = t21 * t28;
    arr42.push(t29);
  }
  return arr42;
}

export function _order_tax(input) {
  let t37 = input["orders"];
  let arr50 = [];
  for (let orders_i39 = 0; orders_i39 < t37.length; orders_i39++) {
    let orders_el38 = t37[orders_i39];
    let t40 = orders_el38["items"];
    let acc45 = 0;
    for (let items_i42 = 0; items_i42 < t40.length; items_i42++) {
      let items_el41 = t40[items_i42];
      let t43 = items_el41["quantity"];
      let t44 = items_el41["unit_price"];
      let t30 = t43 * t44;
      acc45 += t30;
    }
    let t31 = acc45;
    let t46 = orders_el38["shipping_cost"];
    let t23 = t31 + t46;
    let t47 = 1.0;
    let t48 = input["global_discount_rate"];
    let t33 = t47 - t48;
    let t34 = t23 * t33;
    let t49 = 0.15;
    let t36 = t34 * t49;
    arr50.push(t36);
  }
  return arr50;
}

export function _order_totals(input) {
  let t52 = input["orders"];
  let arr65 = [];
  for (let orders_i54 = 0; orders_i54 < t52.length; orders_i54++) {
    let orders_el53 = t52[orders_i54];
    let t55 = orders_el53["items"];
    let acc60 = 0;
    for (let items_i57 = 0; items_i57 < t55.length; items_i57++) {
      let items_el56 = t55[items_i57];
      let t58 = items_el56["quantity"];
      let t59 = items_el56["unit_price"];
      let t45 = t58 * t59;
      acc60 += t45;
    }
    let t46 = acc60;
    let t61 = orders_el53["shipping_cost"];
    let t26 = t46 + t61;
    let t62 = 1.0;
    let t63 = input["global_discount_rate"];
    let t48 = t62 - t63;
    let t49 = t26 * t48;
    let t64 = 0.15;
    let t51 = t49 * t64;
    let t18 = t49 + t51;
    arr65.push(t18);
  }
  return arr65;
}

export function _discount_per_order(input) {
  let t49 = input["orders"];
  let arr61 = [];
  for (let orders_i51 = 0; orders_i51 < t49.length; orders_i51++) {
    let orders_el50 = t49[orders_i51];
    let t52 = orders_el50["items"];
    let acc57 = 0;
    for (let items_i54 = 0; items_i54 < t52.length; items_i54++) {
      let items_el53 = t52[items_i54];
      let t55 = items_el53["quantity"];
      let t56 = items_el53["unit_price"];
      let t44 = t55 * t56;
      acc57 += t44;
    }
    let t45 = acc57;
    let t58 = orders_el50["shipping_cost"];
    let t29 = t45 + t58;
    let t59 = 1.0;
    let t60 = input["global_discount_rate"];
    let t47 = t59 - t60;
    let t48 = t29 * t47;
    let t21 = t29 - t48;
    arr61.push(t21);
  }
  return arr61;
}

export function _total_orders(input) {
  let t26 = input["orders"];
  let acc30 = 0;
  for (let orders_i28 = 0; orders_i28 < t26.length; orders_i28++) {
    let orders_el27 = t26[orders_i28];
    let t29 = orders_el27["id"];
    acc30 += 1;
  }
  let t25 = acc30;
  return t25;
}

export function _total_revenue(input) {
  let t62 = input["orders"];
  let acc75 = 0;
  for (let orders_i64 = 0; orders_i64 < t62.length; orders_i64++) {
    let orders_el63 = t62[orders_i64];
    let t65 = orders_el63["items"];
    let acc70 = 0;
    for (let items_i67 = 0; items_i67 < t65.length; items_i67++) {
      let items_el66 = t65[items_i67];
      let t68 = items_el66["quantity"];
      let t69 = items_el66["unit_price"];
      let t55 = t68 * t69;
      acc70 += t55;
    }
    let t56 = acc70;
    let t71 = orders_el63["shipping_cost"];
    let t35 = t56 + t71;
    let t72 = 1.0;
    let t73 = input["global_discount_rate"];
    let t58 = t72 - t73;
    let t59 = t35 * t58;
    let t74 = 0.15;
    let t61 = t59 * t74;
    let t51 = t59 + t61;
    acc75 += t51;
  }
  let t27 = acc75;
  return t27;
}

export function _total_tax_collected(input) {
  let t52 = input["orders"];
  let acc65 = 0;
  for (let orders_i54 = 0; orders_i54 < t52.length; orders_i54++) {
    let orders_el53 = t52[orders_i54];
    let t55 = orders_el53["items"];
    let acc60 = 0;
    for (let items_i57 = 0; items_i57 < t55.length; items_i57++) {
      let items_el56 = t55[items_i57];
      let t58 = items_el56["quantity"];
      let t59 = items_el56["unit_price"];
      let t45 = t58 * t59;
      acc60 += t45;
    }
    let t46 = acc60;
    let t61 = orders_el53["shipping_cost"];
    let t37 = t46 + t61;
    let t62 = 1.0;
    let t63 = input["global_discount_rate"];
    let t48 = t62 - t63;
    let t49 = t37 * t48;
    let t64 = 0.15;
    let t51 = t49 * t64;
    acc65 += t51;
  }
  let t29 = acc65;
  return t29;
}

export function _total_discount_given(input) {
  let t60 = input["orders"];
  let acc72 = 0;
  for (let orders_i62 = 0; orders_i62 < t60.length; orders_i62++) {
    let orders_el61 = t60[orders_i62];
    let t63 = orders_el61["items"];
    let acc68 = 0;
    for (let items_i65 = 0; items_i65 < t63.length; items_i65++) {
      let items_el64 = t63[items_i65];
      let t66 = items_el64["quantity"];
      let t67 = items_el64["unit_price"];
      let t55 = t66 * t67;
      acc68 += t55;
    }
    let t56 = acc68;
    let t69 = orders_el61["shipping_cost"];
    let t39 = t56 + t69;
    let t70 = 1.0;
    let t71 = input["global_discount_rate"];
    let t58 = t70 - t71;
    let t59 = t39 * t58;
    let t51 = t39 - t59;
    acc72 += t51;
  }
  let t31 = acc72;
  return t31;
}

