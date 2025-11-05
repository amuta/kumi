export function _total_payroll(input) {
  let out = [];
  let t1 = input["departments"];
  t1.forEach((departments_el_2, departments_i_3) => {
    let acc_4 = 0;
    let t5 = departments_el_2["employees"];
    t5.forEach((employees_el_6, employees_i_7) => {
      let t8 = employees_el_6["salary"];
      acc_4 += t8;
    });
    out.push(acc_4);
  });
  return out;
}

export function _payroll_tax(input) {
  let out = [];
  let t10 = input["departments"];
  t10.forEach((departments_el_11, departments_i_12) => {
    let acc40 = 0;
    let t41 = departments_el_11["employees"];
    t41.forEach((t42, t43) => {
      let t44 = t42["salary"];
      acc40 += t44;
    });
    let t15 = acc40 * 0.15;
    out.push(t15);
  });
  return out;
}

export function _manager_count(input) {
  let out = [];
  let t16 = input["departments"];
  t16.forEach((departments_el_17, departments_i_18) => {
    let acc_19 = 0;
    let t20 = departments_el_17["employees"];
    t20.forEach((employees_el_21, employees_i_22) => {
      let t23 = employees_el_21["role"];
      let t25 = t23 == "manager";
      let t28 = t25 ? 1 : 0;
      acc_19 += t28;
    });
    out.push(acc_19);
  });
  return out;
}

export function _department_summary(input) {
  let out = [];
  let t30 = input["departments"];
  t30.forEach((departments_el_31, departments_i_32) => {
    let t33 = departments_el_31["name"];
    let acc48 = 0;
    let t49 = departments_el_31["employees"];
    let acc60 = 0;
    let acc68 = 0;
    t49.forEach((t50, t51) => {
      let t52 = t50["salary"];
      acc48 += t52;
      acc60 += t52;
      let t72 = t50["role"];
      let t74 = t72 == "manager";
      let t77 = t74 ? 1 : 0;
      acc68 += t77;
    });
    let t57 = acc60 * 0.15;
    let t37 = {
      "name": t33,
      "payroll": acc48,
      "tax": t57,
      "managers": acc68
    };
    out.push(t37);
  });
  return out;
}

