export function _double(input) {
  let t7 = input["items"];
  let arr12 = [];
  for (let items_i9 = 0; items_i9 < t7.length; items_i9++) {
    let items_el8 = t7[items_i9];
    let t10 = items_el8["price"];
    let t11 = 2.0;
    let t6 = t10 * t11;
    arr12.push(t6);
  }
  return arr12;
}

export function _dj(input) {
  let t15 = input["items"];
  let arr20 = [];
  for (let items_i17 = 0; items_i17 < t15.length; items_i17++) {
    let items_el16 = t15[items_i17];
    let t18 = items_el16["price"];
    let t19 = 2.0;
    let t14 = t18 * t19;
    arr20.push(t14);
  }
  let arr27 = [];
  for (let items_i22 = 0; items_i22 < t15.length; items_i22++) {
    let items_el21 = t15[items_i22];
    let t23 = input["items"];
    let arr28 = [];
    for (let items__x_i25 = 0; items__x_i25 < t23.length; items__x_i25++) {
      let items__x_el24 = t23[items__x_i25];
      let t26 = arr20[items__x_i25];
      arr28.push(t26);
    }
    arr27.push(arr28);
  }
  return arr27;
}

export function _pair_total(input) {
  let t18 = input["items"];
  let arr23 = [];
  for (let items_i20 = 0; items_i20 < t18.length; items_i20++) {
    let items_el19 = t18[items_i20];
    let t21 = items_el19["price"];
    let t22 = 2.0;
    let t16 = t21 * t22;
    arr23.push(t16);
  }
  let arr31 = [];
  for (let items_i25 = 0; items_i25 < t18.length; items_i25++) {
    let items_el24 = t18[items_i25];
    let t26 = input["items"];
    let acc30 = 0.0;
    for (let items__x_i28 = 0; items__x_i28 < t26.length; items__x_i28++) {
      let items__x_el27 = t26[items__x_i28];
      let t29 = arr23[items__x_i28];
      acc30 += t29;
    }
    arr31.push(acc30);
  }
  return arr31;
}

export function _self_diff(input) {
  let t23 = input["items"];
  let arr28 = [];
  for (let items_i25 = 0; items_i25 < t23.length; items_i25++) {
    let items_el24 = t23[items_i25];
    let t26 = items_el24["price"];
    let t27 = 2.0;
    let t21 = t26 * t27;
    arr28.push(t21);
  }
  let arr37 = [];
  for (let items_i30 = 0; items_i30 < t23.length; items_i30++) {
    let items_el29 = t23[items_i30];
    let t31 = input["items"];
    let acc36 = 0.0;
    for (let items__x_i33 = 0; items__x_i33 < t31.length; items__x_i33++) {
      let items__x_el32 = t31[items__x_i33];
      let t34 = arr28[items__x_i33];
      let t35 = arr28[items_i30];
      let t14 = t34 - t35;
      acc36 += t14;
    }
    arr37.push(acc36);
  }
  return arr37;
}

export function _idx_i(input) {
  let t17 = input["items"];
  let arr21 = [];
  for (let items_i19 = 0; items_i19 < t17.length; items_i19++) {
    let items_el18 = t17[items_i19];
    arr21.push(items_i19);
  }
  return arr21;
}

export function _idx_j(input) {
  let t20 = input["items"];
  let arr26 = [];
  for (let items_i22 = 0; items_i22 < t20.length; items_i22++) {
    let items_el21 = t20[items_i22];
    let t23 = input["items"];
    let arr27 = [];
    for (let items__x_i25 = 0; items__x_i25 < t23.length; items__x_i25++) {
      let items__x_el24 = t23[items__x_i25];
      arr27.push(items__x_i25);
    }
    arr26.push(arr27);
  }
  return arr26;
}

export function _rank(input) {
  let t31 = input["items"];
  let arr40 = [];
  for (let items_i33 = 0; items_i33 < t31.length; items_i33++) {
    let items_el32 = t31[items_i33];
    let t34 = input["items"];
    let acc39 = 0;
    for (let items__x_i36 = 0; items__x_i36 < t34.length; items__x_i36++) {
      let items__x_el35 = t34[items__x_i36];
      let t22 = items__x_i36 < items_i33;
      let t37 = 1;
      let t38 = 0;
      let t27 = t22 ? t37 : t38;
      acc39 += t27;
    }
    arr40.push(acc39);
  }
  return arr40;
}

