export function _dept_total(input) {
  let out = [];
  let t1 = input["depts"];
  t1.forEach((depts_el_2, depts_i_3) => {
    let acc_4 = 0;
    let t5 = depts_el_2["teams"];
    t5.forEach((teams_el_6, teams_i_7) => {
      let t8 = teams_el_6["headcount"];
      acc_4 += t8;
    });
    out.push(acc_4);
  });
  return out;
}

export function _company_total(input) {
  let acc_10 = 0;
  let t11 = input["depts"];
  t11.forEach((depts_el_12, depts_i_13) => {
    let acc_14 = 0;
    let t15 = depts_el_12["teams"];
    t15.forEach((teams_el_16, teams_i_17) => {
      let t18 = teams_el_16["headcount"];
      acc_14 += t18;
    });
    acc_10 += acc_14;
  });
  return acc_10;
}

export function _big_team(input) {
  let out = [];
  let t21 = input["depts"];
  const t28 = 10;
  t21.forEach((depts_el_22, depts_i_23) => {
    let out_1 = [];
    let t24 = depts_el_22["teams"];
    t24.forEach((teams_el_25, teams_i_26) => {
      let t27 = teams_el_25["headcount"];
      let t29 = t27 > t28;
      out_1.push(t29);
    });
    out.push(out_1);
  });
  return out;
}

export function _dept_total_masked(input) {
  let out = [];
  let t30 = input["depts"];
  const t45 = 10;
  const t39 = 0;
  t30.forEach((depts_el_31, depts_i_32) => {
    let acc_33 = 0;
    let t34 = depts_el_31["teams"];
    t34.forEach((teams_el_35, teams_i_36) => {
      let t44 = teams_el_35["headcount"];
      let t46 = t44 > t45;
      let t40 = t46 ? t44 : t39;
      acc_33 += t40;
    });
    out.push(acc_33);
  });
  return out;
}

