export function _dept_total(input) {
  let t7 = input["depts"];
  let arr15 = [];
  for (let depts_i9 = 0; depts_i9 < t7.length; depts_i9++) {
    let depts_el8 = t7[depts_i9];
    let t10 = depts_el8["teams"];
    let acc14 = 0;
    for (let teams_i12 = 0; teams_i12 < t10.length; teams_i12++) {
      let teams_el11 = t10[teams_i12];
      let t13 = teams_el11["headcount"];
      acc14 += t13;
    }
    let t6 = acc14;
    arr15.push(t6);
  }
  return arr15;
}

export function _company_total(input) {
  let t14 = input["depts"];
  let acc22 = 0;
  for (let depts_i16 = 0; depts_i16 < t14.length; depts_i16++) {
    let depts_el15 = t14[depts_i16];
    let t17 = depts_el15["teams"];
    let acc21 = 0;
    for (let teams_i19 = 0; teams_i19 < t17.length; teams_i19++) {
      let teams_el18 = t17[teams_i19];
      let t20 = teams_el18["headcount"];
      acc21 += t20;
    }
    let t12 = acc21;
    acc22 += t12;
  }
  let t13 = acc22;
  return t13;
}

export function _big_team(input) {
  let t22 = input["depts"];
  let arr30 = [];
  for (let depts_i24 = 0; depts_i24 < t22.length; depts_i24++) {
    let depts_el23 = t22[depts_i24];
    let t25 = depts_el23["teams"];
    let arr31 = [];
    for (let teams_i27 = 0; teams_i27 < t25.length; teams_i27++) {
      let teams_el26 = t25[teams_i27];
      let t28 = teams_el26["headcount"];
      let t29 = 10;
      let t21 = t28 > t29;
      arr31.push(t21);
    }
    arr30.push(arr31);
  }
  return arr30;
}

export function _dept_total_masked(input) {
  let t40 = input["depts"];
  let arr50 = [];
  for (let depts_i42 = 0; depts_i42 < t40.length; depts_i42++) {
    let depts_el41 = t40[depts_i42];
    let t43 = depts_el41["teams"];
    let acc49 = 0;
    for (let teams_i45 = 0; teams_i45 < t43.length; teams_i45++) {
      let teams_el44 = t43[teams_i45];
      let t46 = teams_el44["headcount"];
      let t47 = 10;
      let t39 = t46 > t47;
      let t48 = 0;
      let t30 = t39 ? t46 : t48;
      acc49 += t30;
    }
    let t31 = acc49;
    arr50.push(t31);
  }
  return arr50;
}

