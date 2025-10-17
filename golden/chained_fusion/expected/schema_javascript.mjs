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

export function _senior_employee_count(input) {
  let out = [];
  let t24 = input["departments"];
  const t32 = "senior";
  const t34 = 1;
  const t35 = 0;
  t24.forEach((departments_el_25, departments_i_26) => {
    let acc_27 = 0;
    let t28 = departments_el_25["employees"];
    t28.forEach((employees_el_29, employees_i_30) => {
      let t31 = employees_el_29["role"];
      let t33 = t31 == t32;
      let t36 = t33 ? t34 : t35;
      acc_27 += t36;
    });
    out.push(acc_27);
  });
  return out;
}

export function _max_salary(input) {
  let out = [];
  let t38 = input["departments"];
  t38.forEach((departments_el_39, departments_i_40) => {
    let acc_41 = null;
    let t42 = departments_el_39["employees"];
    t42.forEach((employees_el_43, employees_i_44) => {
      let t45 = employees_el_43["salary"];
      if (acc_41 === null || acc_41 === undefined) {
        acc_41 = t45;
      } else {
        acc_41 = (acc_41 === null || t45 > acc_41) ? t45 : acc_41;
      }
    });
    out.push(acc_41);
  });
  return out;
}

export function _department_summary(input) {
  let out = [];
  let t47 = input["departments"];
  const t71 = "manager";
  const t73 = 1;
  const t74 = 0;
  const t84 = "senior";
  t47.forEach((departments_el_48, departments_i_49) => {
    let t50 = departments_el_48["name"];
    let acc58 = 0;
    let t59 = departments_el_48["employees"];
    let acc66 = 0;
    let acc79 = 0;
    let acc92 = null;
    t59.forEach((t60, t61) => {
      let t62 = t60["salary"];
      acc58 += t62;
      let t70 = t60["role"];
      let t72 = t70 == t71;
      let t75 = t72 ? t73 : t74;
      acc66 += t75;
      if (acc92 === null || acc92 === undefined) {
        acc92 = t62;
      } else {
        acc92 = (acc92 === null || t62 > acc92) ? t62 : acc92;
      }
      let t85 = t70 == t84;
      let t88 = t85 ? t73 : t74;
      acc79 += t88;
    });
    let t55 = {
      "name": t50,
      "total_payroll": acc58,
      "manager_count": acc66,
      "senior_count": acc79,
      "top_salary": acc92
    };
    out.push(t55);
  });
  return out;
}

