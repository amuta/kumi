export function _total_payroll(input) {
  let t7 = input["departments"];
  let arr15 = [];
  for (let departments_i9 = 0; departments_i9 < t7.length; departments_i9++) {
    let departments_el8 = t7[departments_i9];
    let t10 = departments_el8["employees"];
    let acc14 = 0;
    for (let employees_i12 = 0; employees_i12 < t10.length; employees_i12++) {
      let employees_el11 = t10[employees_i12];
      let t13 = employees_el11["salary"];
      acc14 += t13;
    }
    let t6 = acc14;
    arr15.push(t6);
  }
  return arr15;
}

export function _payroll_tax(input) {
  let t17 = input["departments"];
  let arr26 = [];
  for (let departments_i19 = 0; departments_i19 < t17.length; departments_i19++) {
    let departments_el18 = t17[departments_i19];
    let t20 = departments_el18["employees"];
    let acc24 = 0;
    for (let employees_i22 = 0; employees_i22 < t20.length; employees_i22++) {
      let employees_el21 = t20[employees_i22];
      let t23 = employees_el21["salary"];
      acc24 += t23;
    }
    let t16 = acc24;
    let t25 = 0.15;
    let t10 = t16 * t25;
    arr26.push(t10);
  }
  return arr26;
}

export function _manager_count(input) {
  let t25 = input["departments"];
  let arr36 = [];
  for (let departments_i27 = 0; departments_i27 < t25.length; departments_i27++) {
    let departments_el26 = t25[departments_i27];
    let t28 = departments_el26["employees"];
    let acc35 = 0;
    for (let employees_i30 = 0; employees_i30 < t28.length; employees_i30++) {
      let employees_el29 = t28[employees_i30];
      let t31 = employees_el29["role"];
      let t32 = "manager";
      let t18 = t31 == t32;
      let t33 = 1;
      let t34 = 0;
      let t23 = t18 ? t33 : t34;
      acc35 += t23;
    }
    let t24 = acc35;
    arr36.push(t24);
  }
  return arr36;
}

export function _department_summary(input) {
  let t61 = input["departments"];
  let arr78 = [];
  for (let departments_i63 = 0; departments_i63 < t61.length; departments_i63++) {
    let departments_el62 = t61[departments_i63];
    let t64 = departments_el62["employees"];
    let acc68 = 0;
    for (let employees_i66 = 0; employees_i66 < t64.length; employees_i66++) {
      let employees_el65 = t64[employees_i66];
      let t67 = employees_el65["salary"];
      acc68 += t67;
    }
    let t37 = acc68;
    let t69 = 0.15;
    let t46 = t37 * t69;
    let acc76 = 0;
    for (let employees_i71 = 0; employees_i71 < t64.length; employees_i71++) {
      let employees_el70 = t64[employees_i71];
      let t72 = employees_el70["role"];
      let t73 = "manager";
      let t54 = t72 == t73;
      let t74 = 1;
      let t75 = 0;
      let t59 = t54 ? t74 : t75;
      acc76 += t59;
    }
    let t60 = acc76;
    let t77 = departments_el62["name"];
    let t31 = { "name": t77, "payroll": t37, "tax": t46, "managers": t60 };
    arr78.push(t31);
  }
  return arr78;
}

