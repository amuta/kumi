export function _shift_cols_right_zero(input) {
  let t5 = input["rows"];
  let arr14 = [];
  for (let rows_i7 = 0; rows_i7 < t5.length; rows_i7++) {
    let rows_el6 = t5[rows_i7];
    let arr15 = [];
    for (let col_i9 = 0; col_i9 < rows_el6.length; col_i9++) {
      let col_el8 = rows_el6[col_i9];
      let t10 = rows_el6.length;
      let t11 = rows_el6[Math.min(Math.max(col_i9 - (1), 0), t10 - 1)];
      let t12_j = col_i9 - (1);
      let t12 = t12_j >= 0 && t12_j < t10;
      let t13 = 0;
      let t1 = t12 ? t11 : t13;
      arr15.push(t1);
    }
    arr14.push(arr15);
  }
  return arr14;
}

export function _shift_cols_right_clamp(input) {
  let t9 = input["rows"];
  let arr16 = [];
  for (let rows_i11 = 0; rows_i11 < t9.length; rows_i11++) {
    let rows_el10 = t9[rows_i11];
    let arr17 = [];
    for (let col_i13 = 0; col_i13 < rows_el10.length; col_i13++) {
      let col_el12 = rows_el10[col_i13];
      let t14 = rows_el10.length;
      let t15 = rows_el10[Math.min(Math.max(col_i13 - (1), 0), t14 - 1)];
      let t5 = t15;
      arr17.push(t5);
    }
    arr16.push(arr17);
  }
  return arr16;
}

export function _shift_cols_right_wrap(input) {
  let t13 = input["rows"];
  let arr20 = [];
  for (let rows_i15 = 0; rows_i15 < t13.length; rows_i15++) {
    let rows_el14 = t13[rows_i15];
    let arr21 = [];
    for (let col_i17 = 0; col_i17 < rows_el14.length; col_i17++) {
      let col_el16 = rows_el14[col_i17];
      let t18 = rows_el14.length;
      let t19 = rows_el14[(((col_i17 - (1)) % t18) + t18) % t18];
      let t9 = t19;
      arr21.push(t9);
    }
    arr20.push(arr21);
  }
  return arr20;
}

export function _shift_cols_left_zero(input) {
  let t17 = input["rows"];
  let arr26 = [];
  for (let rows_i19 = 0; rows_i19 < t17.length; rows_i19++) {
    let rows_el18 = t17[rows_i19];
    let arr27 = [];
    for (let col_i21 = 0; col_i21 < rows_el18.length; col_i21++) {
      let col_el20 = rows_el18[col_i21];
      let t22 = rows_el18.length;
      let t23 = rows_el18[Math.min(Math.max(col_i21 - (-1), 0), t22 - 1)];
      let t24_j = col_i21 - (-1);
      let t24 = t24_j >= 0 && t24_j < t22;
      let t25 = 0;
      let t13 = t24 ? t23 : t25;
      arr27.push(t13);
    }
    arr26.push(arr27);
  }
  return arr26;
}

export function _shift_cols_left_clamp(input) {
  let t21 = input["rows"];
  let arr28 = [];
  for (let rows_i23 = 0; rows_i23 < t21.length; rows_i23++) {
    let rows_el22 = t21[rows_i23];
    let arr29 = [];
    for (let col_i25 = 0; col_i25 < rows_el22.length; col_i25++) {
      let col_el24 = rows_el22[col_i25];
      let t26 = rows_el22.length;
      let t27 = rows_el22[Math.min(Math.max(col_i25 - (-1), 0), t26 - 1)];
      let t17 = t27;
      arr29.push(t17);
    }
    arr28.push(arr29);
  }
  return arr28;
}

export function _shift_cols_left_wrap(input) {
  let t25 = input["rows"];
  let arr32 = [];
  for (let rows_i27 = 0; rows_i27 < t25.length; rows_i27++) {
    let rows_el26 = t25[rows_i27];
    let arr33 = [];
    for (let col_i29 = 0; col_i29 < rows_el26.length; col_i29++) {
      let col_el28 = rows_el26[col_i29];
      let t30 = rows_el26.length;
      let t31 = rows_el26[(((col_i29 - (-1)) % t30) + t30) % t30];
      let t21 = t31;
      arr33.push(t21);
    }
    arr32.push(arr33);
  }
  return arr32;
}

export function _shift_rows_down_zero(input) {
  let t29 = input["rows"];
  let arr40 = [];
  for (let rows_i31 = 0; rows_i31 < t29.length; rows_i31++) {
    let rows_el30 = t29[rows_i31];
    let arr41 = [];
    for (let col_i33 = 0; col_i33 < rows_el30.length; col_i33++) {
      let col_el32 = rows_el30[col_i33];
      let t34 = input["rows"];
      let t35 = t34.length;
      let t36 = t34[Math.min(Math.max(rows_i31 - (1), 0), t35 - 1)];
      let t37 = t36[col_i33];
      let t38_j = rows_i31 - (1);
      let t38 = t38_j >= 0 && t38_j < t35;
      let t39 = 0;
      let t25 = t38 ? t37 : t39;
      arr41.push(t25);
    }
    arr40.push(arr41);
  }
  return arr40;
}

export function _shift_rows_down_clamp(input) {
  let t33 = input["rows"];
  let arr42 = [];
  for (let rows_i35 = 0; rows_i35 < t33.length; rows_i35++) {
    let rows_el34 = t33[rows_i35];
    let arr43 = [];
    for (let col_i37 = 0; col_i37 < rows_el34.length; col_i37++) {
      let col_el36 = rows_el34[col_i37];
      let t38 = input["rows"];
      let t39 = t38.length;
      let t40 = t38[Math.min(Math.max(rows_i35 - (1), 0), t39 - 1)];
      let t41 = t40[col_i37];
      let t29 = t41;
      arr43.push(t29);
    }
    arr42.push(arr43);
  }
  return arr42;
}

export function _shift_rows_down_wrap(input) {
  let t37 = input["rows"];
  let arr46 = [];
  for (let rows_i39 = 0; rows_i39 < t37.length; rows_i39++) {
    let rows_el38 = t37[rows_i39];
    let arr47 = [];
    for (let col_i41 = 0; col_i41 < rows_el38.length; col_i41++) {
      let col_el40 = rows_el38[col_i41];
      let t42 = input["rows"];
      let t43 = t42.length;
      let t44 = t42[(((rows_i39 - (1)) % t43) + t43) % t43];
      let t45 = t44[col_i41];
      let t33 = t45;
      arr47.push(t33);
    }
    arr46.push(arr47);
  }
  return arr46;
}

export function _shift_rows_up_zero(input) {
  let t41 = input["rows"];
  let arr52 = [];
  for (let rows_i43 = 0; rows_i43 < t41.length; rows_i43++) {
    let rows_el42 = t41[rows_i43];
    let arr53 = [];
    for (let col_i45 = 0; col_i45 < rows_el42.length; col_i45++) {
      let col_el44 = rows_el42[col_i45];
      let t46 = input["rows"];
      let t47 = t46.length;
      let t48 = t46[Math.min(Math.max(rows_i43 - (-1), 0), t47 - 1)];
      let t49 = t48[col_i45];
      let t50_j = rows_i43 - (-1);
      let t50 = t50_j >= 0 && t50_j < t47;
      let t51 = 0;
      let t37 = t50 ? t49 : t51;
      arr53.push(t37);
    }
    arr52.push(arr53);
  }
  return arr52;
}

export function _shift_rows_up_clamp(input) {
  let t45 = input["rows"];
  let arr54 = [];
  for (let rows_i47 = 0; rows_i47 < t45.length; rows_i47++) {
    let rows_el46 = t45[rows_i47];
    let arr55 = [];
    for (let col_i49 = 0; col_i49 < rows_el46.length; col_i49++) {
      let col_el48 = rows_el46[col_i49];
      let t50 = input["rows"];
      let t51 = t50.length;
      let t52 = t50[Math.min(Math.max(rows_i47 - (-1), 0), t51 - 1)];
      let t53 = t52[col_i49];
      let t41 = t53;
      arr55.push(t41);
    }
    arr54.push(arr55);
  }
  return arr54;
}

export function _shift_rows_up_wrap(input) {
  let t49 = input["rows"];
  let arr58 = [];
  for (let rows_i51 = 0; rows_i51 < t49.length; rows_i51++) {
    let rows_el50 = t49[rows_i51];
    let arr59 = [];
    for (let col_i53 = 0; col_i53 < rows_el50.length; col_i53++) {
      let col_el52 = rows_el50[col_i53];
      let t54 = input["rows"];
      let t55 = t54.length;
      let t56 = t54[(((rows_i51 - (-1)) % t55) + t55) % t55];
      let t57 = t56[col_i53];
      let t45 = t57;
      arr59.push(t45);
    }
    arr58.push(arr59);
  }
  return arr58;
}

