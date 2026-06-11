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

export function _manager_count(input) {
  let t21 = input["departments"];
  let arr32 = [];
  for (let departments_i23 = 0; departments_i23 < t21.length; departments_i23++) {
    let departments_el22 = t21[departments_i23];
    let t24 = departments_el22["employees"];
    let acc31 = 0;
    for (let employees_i26 = 0; employees_i26 < t24.length; employees_i26++) {
      let employees_el25 = t24[employees_i26];
      let t27 = employees_el25["role"];
      let t28 = "manager";
      let t14 = t27 == t28;
      let t29 = 1;
      let t30 = 0;
      let t19 = t14 ? t29 : t30;
      acc31 += t19;
    }
    let t20 = acc31;
    arr32.push(t20);
  }
  return arr32;
}

export function _department_summary(input) {
  let t47 = input["departments"];
  let arr61 = [];
  for (let departments_i49 = 0; departments_i49 < t47.length; departments_i49++) {
    let departments_el48 = t47[departments_i49];
    let t50 = departments_el48["employees"];
    let acc54 = 0;
    let acc59 = 0;
    for (let employees_i52 = 0; employees_i52 < t50.length; employees_i52++) {
      let employees_el51 = t50[employees_i52];
      let t53 = employees_el51["salary"];
      acc54 += t53;
      let t55 = employees_el51["role"];
      let t56 = "manager";
      let t40 = t55 == t56;
      let t57 = 1;
      let t58 = 0;
      let t45 = t40 ? t57 : t58;
      acc59 += t45;
    }
    let t32 = acc54;
    let t46 = acc59;
    let t60 = departments_el48["name"];
    let t26 = { "name": t60, "total_payroll": t32, "manager_count": t46 };
    arr61.push(t26);
  }
  return arr61;
}

