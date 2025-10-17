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

export function _manager_count(input) {
  let out = [];
  let t10 = input["departments"];
  const t18 = "manager";
  const t20 = 1;
  const t21 = 0;
  t10.forEach((departments_el_11, departments_i_12) => {
    let acc_13 = 0;
    let t14 = departments_el_11["employees"];
    t14.forEach((employees_el_15, employees_i_16) => {
      let t17 = employees_el_15["role"];
      let t19 = t17 == t18;
      let t22 = t19 ? t20 : t21;
      acc_13 += t22;
    });
    out.push(acc_13);
  });
  return out;
}

export function _department_summary(input) {
  let out = [];
  let t24 = input["departments"];
  const t46 = "manager";
  const t48 = 1;
  const t49 = 0;
  t24.forEach((departments_el_25, departments_i_26) => {
    let t27 = departments_el_25["name"];
    let acc33 = 0;
    let t34 = departments_el_25["employees"];
    let acc41 = 0;
    t34.forEach((t35, t36) => {
      let t37 = t35["salary"];
      acc33 += t37;
      let t45 = t35["role"];
      let t47 = t45 == t46;
      let t50 = t47 ? t48 : t49;
      acc41 += t50;
    });
    let t30 = {
      "name": t27,
      "total_payroll": acc33,
      "manager_count": acc41
    };
    out.push(t30);
  });
  return out;
}

