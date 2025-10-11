export function _v_sum_y(input) {
  let out = [];
  let t1 = input["x"];
  t1.forEach((x_el_2, x_i_3) => {
    let acc_4 = 0;
    x_el_2.forEach((y_el_5, y_i_6) => {
      acc_4 += y_el_5;
    });
    out.push(acc_4);
  });
  return out;
}

