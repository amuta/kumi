export function _global_offset_plus(input) {
  let t1 = input["global_offset"];
  const t2 = 1.0;
  let t3 = t1 + t2;
  return t3;
}

export function _batch_bias(input) {
  let out = [];
  let t4 = input["batch"];
  let t54 = input["global_offset"];
  const t55 = 1.0;
  let t56 = t54 + t55;
  t4.forEach((batch_el_5, batch_i_6) => {
    let t7 = batch_el_5["mean"];
    let t9 = t7 + t56;
    out.push(t9);
  });
  return out;
}

export function _row_scale2(input) {
  let out = [];
  let t10 = input["batch"];
  const t17 = 2.0;
  t10.forEach((batch_el_11, batch_i_12) => {
    let out_1 = [];
    let t13 = batch_el_11["row"];
    t13.forEach((row_el_14, row_i_15) => {
      let t16 = row_el_14["scale"];
      let t18 = t16 * t17;
      out_1.push(t18);
    });
    out.push(out_1);
  });
  return out;
}

export function _elem_affine(input) {
  let out = [];
  let t19 = input["batch"];
  let t66 = input["global_offset"];
  const t67 = 1.0;
  let t68 = t66 + t67;
  const t60 = 2.0;
  t19.forEach((batch_el_20, batch_i_21) => {
    let out_1 = [];
    let t22 = batch_el_20["row"];
    let t64 = batch_el_20["mean"];
    let t65 = t64 + t68;
    t22.forEach((row_el_23, row_i_24) => {
      let out_2 = [];
      let t25 = row_el_23["col"];
      let t59 = row_el_23["scale"];
      let t61 = t59 * t60;
      t25.forEach((col_el_26, col_i_27) => {
        let t28 = col_el_26["val"];
        let t30 = t28 * t61;
        let t32 = t30 + t65;
        out_2.push(t32);
      });
      out_1.push(out_2);
    });
    out.push(out_1);
  });
  return out;
}

export function _row_sum_affine(input) {
  let out = [];
  let t33 = input["batch"];
  let t86 = input["global_offset"];
  const t87 = 1.0;
  let t88 = t86 + t87;
  const t80 = 2.0;
  t33.forEach((batch_el_34, batch_i_35) => {
    let out_1 = [];
    let t36 = batch_el_34["row"];
    let t84 = batch_el_34["mean"];
    let t85 = t84 + t88;
    t36.forEach((row_el_37, row_i_38) => {
      let acc_39 = 0.0;
      let t40 = row_el_37["col"];
      let t79 = row_el_37["scale"];
      let t81 = t79 * t80;
      t40.forEach((col_el_41, col_i_42) => {
        let t72 = col_el_41["val"];
        let t74 = t72 * t81;
        let t76 = t74 + t85;
        acc_39 += t76;
      });
      out_1.push(acc_39);
    });
    out.push(out_1);
  });
  return out;
}

export function _batch_total_affine(input) {
  let out = [];
  let t45 = input["batch"];
  let t115 = input["global_offset"];
  const t116 = 1.0;
  let t117 = t115 + t116;
  const t109 = 2.0;
  t45.forEach((batch_el_46, batch_i_47) => {
    let acc_48 = 0.0;
    let t49 = batch_el_46["row"];
    let t113 = batch_el_46["mean"];
    let t114 = t113 + t117;
    t49.forEach((row_el_50, row_i_51) => {
      let acc92 = 0.0;
      let t93 = row_el_50["col"];
      let t108 = row_el_50["scale"];
      let t110 = t108 * t109;
      t93.forEach((t94, t95) => {
        let t101 = t94["val"];
        let t103 = t101 * t110;
        let t105 = t103 + t114;
        acc92 += t105;
      });
      acc_48 += acc92;
    });
    out.push(acc_48);
  });
  return out;
}

