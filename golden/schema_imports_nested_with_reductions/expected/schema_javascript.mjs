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

export function _total_before_tax(input) {
  let t16 = input["orders"];
  let acc25 = 0;
  for (let orders_i18 = 0; orders_i18 < t16.length; orders_i18++) {
    let orders_el17 = t16[orders_i18];
    let t19 = orders_el17["items"];
    let acc24 = 0;
    for (let items_i21 = 0; items_i21 < t19.length; items_i21++) {
      let items_el20 = t19[items_i21];
      let t22 = items_el20["quantity"];
      let t23 = items_el20["unit_price"];
      let t14 = t22 * t23;
      acc24 += t14;
    }
    let t15 = acc24;
    acc25 += t15;
  }
  let t6 = acc25;
  return t6;
}

export function _tax_for_all(input) {
  let t21 = input["orders"];
  let acc30 = 0;
  for (let orders_i23 = 0; orders_i23 < t21.length; orders_i23++) {
    let orders_el22 = t21[orders_i23];
    let t24 = orders_el22["items"];
    let acc29 = 0;
    for (let items_i26 = 0; items_i26 < t24.length; items_i26++) {
      let items_el25 = t24[items_i26];
      let t27 = items_el25["quantity"];
      let t28 = items_el25["unit_price"];
      let t17 = t27 * t28;
      acc29 += t17;
    }
    let t18 = acc29;
    acc30 += t18;
  }
  let t13 = acc30;
  let t31 = 0.15;
  let t20 = t13 * t31;
  return t20;
}

export function _grand_total(input) {
  let t30 = input["orders"];
  let acc39 = 0;
  for (let orders_i32 = 0; orders_i32 < t30.length; orders_i32++) {
    let orders_el31 = t30[orders_i32];
    let t33 = orders_el31["items"];
    let acc38 = 0;
    for (let items_i35 = 0; items_i35 < t33.length; items_i35++) {
      let items_el34 = t33[items_i35];
      let t36 = items_el34["quantity"];
      let t37 = items_el34["unit_price"];
      let t26 = t36 * t37;
      acc38 += t26;
    }
    let t27 = acc38;
    acc39 += t27;
  }
  let t16 = acc39;
  let t40 = 0.15;
  let t29 = t16 * t40;
  let t11 = t16 + t29;
  return t11;
}

