export function _dept_headcount(input) {
  let out = [];
  let t1 = input["departments"];
  t1.forEach((departments_el_2, departments_i_3) => {
    let acc_4 = 0;
    let t5 = departments_el_2["teams"];
    t5.forEach((teams_el_6, teams_i_7) => {
      let t8 = teams_el_6["headcount"];
      acc_4 += t8;
    });
    out.push(acc_4);
  });
  return out;
}

export function _teams_per_dept(input) {
  let out = [];
  let t10 = input["departments"];
  t10.forEach((departments_el_11, departments_i_12) => {
    let acc_13 = 0;
    let t14 = departments_el_11["teams"];
    t14.forEach((teams_el_15, teams_i_16) => {
      let t17 = teams_el_15["team_name"];
      acc_13 += 1;
    });
    out.push(acc_13);
  });
  return out;
}

export function _avg_headcount_per_dept(input) {
  let out = [];
  let t19 = input["departments"];
  t19.forEach((departments_el_20, departments_i_21) => {
    let acc36 = 0;
    let t37 = departments_el_20["teams"];
    let acc44 = 0;
    t37.forEach((t38, t39) => {
      let t40 = t38["headcount"];
      acc36 += t40;
      let t48 = t38["team_name"];
      acc44 += 1;
    });
    let t24 = acc36 / acc44;
    out.push(t24);
  });
  return out;
}

export function _is_above_average_team(input) {
  let out = [];
  let t25 = input["departments"];
  t25.forEach((departments_el_26, departments_i_27) => {
    let out_1 = [];
    let t28 = departments_el_26["teams"];
    let acc56 = 0;
    let acc64 = 0;
    t28.forEach((t58, t59) => {
      let t60 = t58["headcount"];
      acc56 += t60;
      let t68 = t58["team_name"];
      acc64 += 1;
    });
    let t53 = acc56 / acc64;
    t28.forEach((teams_el_29, teams_i_30) => {
      let t31 = teams_el_29["headcount"];
      let t33 = t31 > t53;
      out_1.push(t33);
    });
    out.push(out_1);
  });
  return out;
}

