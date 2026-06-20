export function _v_sum_y(input) {
  let t5 = input["x"];
  let arr11 = [];
  for (let x_i7 = 0; x_i7 < t5.length; x_i7++) {
    let x_el6 = t5[x_i7];
    let acc10 = 0;
    for (let y_i9 = 0; y_i9 < x_el6.length; y_i9++) {
      let y_el8 = x_el6[y_i9];
      acc10 += y_el8;
    }
    arr11.push(acc10);
  }
  return arr11;
}

