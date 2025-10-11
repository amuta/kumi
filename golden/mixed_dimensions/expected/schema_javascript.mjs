export function _sum_numbers(input) {
  let acc_1 = 0;
  let t2 = input["numbers"];
  t2.forEach((numbers_el_3, numbers_i_4) => {
    let t5 = numbers_el_3["value"];
    acc_1 += t5;
  });
  return acc_1;
}

export function _matrix_sums(input) {
  let out = [];
  let t7 = input["matrix"];
  t7.forEach((matrix_el_8, matrix_i_9) => {
    let acc_10 = 0;
    let t11 = matrix_el_8["row"];
    t11.forEach((row_el_12, row_i_13) => {
      let t14 = row_el_12["cell"];
      acc_10 += t14;
    });
    out.push(acc_10);
  });
  return out;
}

export function _mixed_array(input) {
  let out = [];
  let t16 = input["matrix"];
  let acc28 = 0;
  let t29 = input["numbers"];
  t29.forEach((numbers_el_3, numbers_i_4) => {
    let t30 = numbers_el_3["value"];
    acc28 += t30;
  });
  let t22 = input["scalar_val"];
  t16.forEach((matrix_el_17, matrix_i_18) => {
    let out_1 = [];
    let t19 = matrix_el_17["row"];
    t19.forEach((row_el_20, row_i_21) => {
      let t24 = row_el_20["cell"];
      let t25 = [t22, acc28, t24];
      out_1.push(t25);
    });
    out.push(out_1);
  });
  return out;
}

export function _constant(input) {
  const t26 = 42;
  return t26;
}

