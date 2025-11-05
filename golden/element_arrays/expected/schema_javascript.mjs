export function _cube(input) {
  let t1 = input["cube"];
  return t1;
}

export function _layer(input) {
  let out = [];
  let t2 = input["cube"];
  t2.forEach((cube_el_3, cube_i_4) => {
    out.push(cube_el_3);
  });
  return out;
}

export function _row(input) {
  let out = [];
  let t5 = input["cube"];
  t5.forEach((cube_el_6, cube_i_7) => {
    let out_1 = [];
    cube_el_6.forEach((layer_el_8, layer_i_9) => {
      out_1.push(layer_el_8);
    });
    out.push(out_1);
  });
  return out;
}

export function _cell(input) {
  let out = [];
  let t10 = input["cube"];
  t10.forEach((cube_el_11, cube_i_12) => {
    let out_1 = [];
    cube_el_11.forEach((layer_el_13, layer_i_14) => {
      let out_2 = [];
      layer_el_13.forEach((row_el_15, row_i_16) => {
        out_2.push(row_el_15);
      });
      out_1.push(out_2);
    });
    out.push(out_1);
  });
  return out;
}

export function _cell_over_limit(input) {
  let out = [];
  let t17 = input["cube"];
  t17.forEach((cube_el_18, cube_i_19) => {
    let out_1 = [];
    cube_el_18.forEach((layer_el_20, layer_i_21) => {
      let out_2 = [];
      layer_el_20.forEach((row_el_22, row_i_23) => {
        let t25 = row_el_22 > 100;
        out_2.push(t25);
      });
      out_1.push(out_2);
    });
    out.push(out_1);
  });
  return out;
}

export function _cell_sum(input) {
  let out = [];
  let t26 = input["cube"];
  t26.forEach((cube_el_27, cube_i_28) => {
    let out_1 = [];
    cube_el_27.forEach((layer_el_29, layer_i_30) => {
      let acc_31 = 0;
      layer_el_29.forEach((row_el_32, row_i_33) => {
        let t57 = row_el_32 > 100;
        let t36 = t57 ? row_el_32 : 0;
        acc_31 += t36;
      });
      out_1.push(acc_31);
    });
    out.push(out_1);
  });
  return out;
}

export function _count_over_limit(input) {
  let acc_38 = 0;
  let t39 = input["cube"];
  t39.forEach((cube_el_40, cube_i_41) => {
    let acc_42 = 0;
    cube_el_40.forEach((layer_el_43, layer_i_44) => {
      let acc_45 = 0;
      layer_el_43.forEach((row_el_46, row_i_47) => {
        let t60 = row_el_46 > 100;
        let t51 = t60 ? 1 : 0;
        acc_45 += t51;
      });
      acc_42 += acc_45;
    });
    acc_38 += acc_42;
  });
  return acc_38;
}

