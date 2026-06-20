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
    arr15.push(acc14);
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
    arr32.push(acc31);
  }
  return arr32;
}

export function _senior_employee_count(input) {
  let t35 = input["departments"];
  let arr46 = [];
  for (let departments_i37 = 0; departments_i37 < t35.length; departments_i37++) {
    let departments_el36 = t35[departments_i37];
    let t38 = departments_el36["employees"];
    let acc45 = 0;
    for (let employees_i40 = 0; employees_i40 < t38.length; employees_i40++) {
      let employees_el39 = t38[employees_i40];
      let t41 = employees_el39["role"];
      let t42 = "senior";
      let t28 = t41 == t42;
      let t43 = 1;
      let t44 = 0;
      let t33 = t28 ? t43 : t44;
      acc45 += t33;
    }
    arr46.push(acc45);
  }
  return arr46;
}

export function _max_salary(input) {
  let t41 = input["departments"];
  let arr49 = [];
  for (let departments_i43 = 0; departments_i43 < t41.length; departments_i43++) {
    let departments_el42 = t41[departments_i43];
    let t44 = departments_el42["employees"];
    let acc48 = null;
    for (let employees_i46 = 0; employees_i46 < t44.length; employees_i46++) {
      let employees_el45 = t44[employees_i46];
      let t47 = employees_el45["salary"];
      acc48 = (t47 !== null && (acc48 === null || t47 > acc48)) ? t47 : acc48;
    }
    arr49.push(acc48);
  }
  return arr49;
}

export function _department_summary(input) {
  let t89 = input["departments"];
  let arr106 = [];
  for (let departments_i91 = 0; departments_i91 < t89.length; departments_i91++) {
    let departments_el90 = t89[departments_i91];
    let t92 = departments_el90["employees"];
    let acc96 = 0;
    let acc101 = 0;
    let acc103 = 0;
    let acc104 = null;
    for (let employees_i94 = 0; employees_i94 < t92.length; employees_i94++) {
      let employees_el93 = t92[employees_i94];
      let t95 = employees_el93["salary"];
      acc96 += t95;
      let t97 = employees_el93["role"];
      let t98 = "manager";
      let t62 = t97 == t98;
      let t99 = 1;
      let t100 = 0;
      let t67 = t62 ? t99 : t100;
      acc101 += t67;
      let t102 = "senior";
      let t76 = t97 == t102;
      let t81 = t76 ? t99 : t100;
      acc103 += t81;
      acc104 = (t95 !== null && (acc104 === null || t95 > acc104)) ? t95 : acc104;
    }
    let t105 = departments_el90["name"];
    let t48 = { "name": t105, "total_payroll": acc96, "manager_count": acc101, "senior_count": acc103, "top_salary": acc104 };
    arr106.push(t48);
  }
  return arr106;
}

