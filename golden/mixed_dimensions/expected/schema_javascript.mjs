export function _sum_numbers(input) {
  let t5 = input["numbers"];
  let acc9 = 0;
  for (let numbers_i7 = 0; numbers_i7 < t5.length; numbers_i7++) {
    let numbers_el6 = t5[numbers_i7];
    let t8 = numbers_el6["value"];
    acc9 += t8;
  }
  return acc9;
}

export function _matrix_sums(input) {
  let t11 = input["matrix"];
  let arr19 = [];
  for (let matrix_i13 = 0; matrix_i13 < t11.length; matrix_i13++) {
    let matrix_el12 = t11[matrix_i13];
    let t14 = matrix_el12["row"];
    let acc18 = 0.0;
    for (let row_i16 = 0; row_i16 < t14.length; row_i16++) {
      let row_el15 = t14[row_i16];
      let t17 = row_el15["cell"];
      acc18 += t17;
    }
    arr19.push(acc18);
  }
  return arr19;
}

export function _mixed_array(input) {
  let t23 = input["numbers"];
  let acc27 = 0;
  for (let numbers_i25 = 0; numbers_i25 < t23.length; numbers_i25++) {
    let numbers_el24 = t23[numbers_i25];
    let t26 = numbers_el24["value"];
    acc27 += t26;
  }
  let t28 = input["matrix"];
  let arr36 = [];
  for (let matrix_i30 = 0; matrix_i30 < t28.length; matrix_i30++) {
    let matrix_el29 = t28[matrix_i30];
    let t31 = matrix_el29["row"];
    let arr37 = [];
    for (let row_i33 = 0; row_i33 < t31.length; row_i33++) {
      let row_el32 = t31[row_i33];
      let t34 = input["scalar_val"];
      let t35 = row_el32["cell"];
      let t18 = [t34, acc27, t35];
      arr37.push(t18);
    }
    arr36.push(arr37);
  }
  return arr36;
}

export function _constant(input) {
  let t20 = 42;
  return t20;
}

