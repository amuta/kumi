export function _dept_headcount(input) {
  let t7 = input["departments"];
  let arr15 = [];
  for (let departments_i9 = 0; departments_i9 < t7.length; departments_i9++) {
    let departments_el8 = t7[departments_i9];
    let t10 = departments_el8["teams"];
    let acc14 = 0;
    for (let teams_i12 = 0; teams_i12 < t10.length; teams_i12++) {
      let teams_el11 = t10[teams_i12];
      let t13 = teams_el11["headcount"];
      acc14 += t13;
    }
    arr15.push(acc14);
  }
  return arr15;
}

export function _teams_per_dept(input) {
  let t13 = input["departments"];
  let arr21 = [];
  for (let departments_i15 = 0; departments_i15 < t13.length; departments_i15++) {
    let departments_el14 = t13[departments_i15];
    let t16 = departments_el14["teams"];
    let acc20 = 0;
    for (let teams_i18 = 0; teams_i18 < t16.length; teams_i18++) {
      let teams_el17 = t16[teams_i18];
      let t19 = teams_el17["team_name"];
      acc20 += 1;
    }
    arr21.push(acc20);
  }
  return arr21;
}

export function _avg_headcount_per_dept(input) {
  let t28 = input["departments"];
  let arr38 = [];
  for (let departments_i30 = 0; departments_i30 < t28.length; departments_i30++) {
    let departments_el29 = t28[departments_i30];
    let t31 = departments_el29["teams"];
    let acc35 = 0;
    let acc37 = 0;
    for (let teams_i33 = 0; teams_i33 < t31.length; teams_i33++) {
      let teams_el32 = t31[teams_i33];
      let t34 = teams_el32["headcount"];
      acc35 += t34;
      let t36 = teams_el32["team_name"];
      acc37 += 1;
    }
    let t15 = acc35 / acc37;
    arr38.push(t15);
  }
  return arr38;
}

export function _is_above_average_team(input) {
  let t37 = input["departments"];
  let arr50 = [];
  for (let departments_i39 = 0; departments_i39 < t37.length; departments_i39++) {
    let departments_el38 = t37[departments_i39];
    let t40 = departments_el38["teams"];
    let acc44 = 0;
    let acc46 = 0;
    for (let teams_i42 = 0; teams_i42 < t40.length; teams_i42++) {
      let teams_el41 = t40[teams_i42];
      let t43 = teams_el41["headcount"];
      acc44 += t43;
      let t45 = teams_el41["team_name"];
      acc46 += 1;
    }
    let t36 = acc44 / acc46;
    let arr51 = [];
    for (let teams_i48 = 0; teams_i48 < t40.length; teams_i48++) {
      let teams_el47 = t40[teams_i48];
      let t49 = teams_el47["headcount"];
      let t23 = t49 > t36;
      arr51.push(t23);
    }
    arr50.push(arr51);
  }
  return arr50;
}

