export function _global_offset_plus(input) {
  let t4 = input["global_offset"];
  let t5 = 1.0;
  let t3 = t4 + t5;
  return t3;
}

export function _batch_bias(input) {
  let t13 = input["global_offset"];
  let t14 = 1.0;
  let t12 = t13 + t14;
  let t15 = input["batch"];
  let arr19 = [];
  for (let batch_i17 = 0; batch_i17 < t15.length; batch_i17++) {
    let batch_el16 = t15[batch_i17];
    let t18 = batch_el16["mean"];
    let t9 = t18 + t12;
    arr19.push(t9);
  }
  return arr19;
}

export function _row_scale2(input) {
  let t18 = input["batch"];
  let arr26 = [];
  for (let batch_i20 = 0; batch_i20 < t18.length; batch_i20++) {
    let batch_el19 = t18[batch_i20];
    let t21 = batch_el19["row"];
    let arr27 = [];
    for (let row_i23 = 0; row_i23 < t21.length; row_i23++) {
      let row_el22 = t21[row_i23];
      let t24 = row_el22["scale"];
      let t25 = 2.0;
      let t17 = t24 * t25;
      arr27.push(t17);
    }
    arr26.push(arr27);
  }
  return arr26;
}

export function _elem_affine(input) {
  let t47 = input["batch"];
  let t59 = input["global_offset"];
  let t60 = 1.0;
  let t44 = t59 + t60;
  let arr76 = [];
  for (let batch_i49 = 0; batch_i49 < t47.length; batch_i49++) {
    let batch_el48 = t47[batch_i49];
    let t50 = batch_el48["row"];
    let arr71 = [];
    for (let row_i52 = 0; row_i52 < t50.length; row_i52++) {
      let row_el51 = t50[row_i52];
      let t53 = row_el51["scale"];
      let t54 = 2.0;
      let t38 = t53 * t54;
      let t55 = row_el51["col"];
      let arr72 = [];
      for (let col_i57 = 0; col_i57 < t55.length; col_i57++) {
        let col_el56 = t55[col_i57];
        let t58 = col_el56["val"];
        let t27 = t58 * t38;
        arr72.push(t27);
      }
      arr71.push(arr72);
    }
    let t63 = batch_el48["mean"];
    let t46 = t63 + t44;
    let t64 = batch_el48["row"];
    let arr77 = [];
    for (let row_i66 = 0; row_i66 < t64.length; row_i66++) {
      let row_el65 = t64[row_i66];
      let t67 = row_el65["col"];
      let arr78 = [];
      for (let col_i69 = 0; col_i69 < t67.length; col_i69++) {
        let col_el68 = t67[col_i69];
        let t74 = arr71[row_i66];
        let t75 = t74[col_i69];
        let t30 = t75 + t46;
        arr78.push(t30);
      }
      arr77.push(arr78);
    }
    arr76.push(arr77);
  }
  return arr76;
}

export function _row_sum_affine(input) {
  let t60 = input["batch"];
  let t72 = input["global_offset"];
  let t73 = 1.0;
  let t55 = t72 + t73;
  let arr90 = [];
  for (let batch_i62 = 0; batch_i62 < t60.length; batch_i62++) {
    let batch_el61 = t60[batch_i62];
    let t63 = batch_el61["row"];
    let arr84 = [];
    for (let row_i65 = 0; row_i65 < t63.length; row_i65++) {
      let row_el64 = t63[row_i65];
      let t66 = row_el64["scale"];
      let t67 = 2.0;
      let t47 = t66 * t67;
      let t68 = row_el64["col"];
      let arr85 = [];
      for (let col_i70 = 0; col_i70 < t68.length; col_i70++) {
        let col_el69 = t68[col_i70];
        let t71 = col_el69["val"];
        let t49 = t71 * t47;
        arr85.push(t49);
      }
      arr84.push(arr85);
    }
    let t76 = batch_el61["mean"];
    let t57 = t76 + t55;
    let t77 = batch_el61["row"];
    let arr91 = [];
    for (let row_i79 = 0; row_i79 < t77.length; row_i79++) {
      let row_el78 = t77[row_i79];
      let t80 = row_el78["col"];
      let acc89 = 0.0;
      for (let col_i82 = 0; col_i82 < t80.length; col_i82++) {
        let col_el81 = t80[col_i82];
        let t87 = arr84[row_i79];
        let t88 = t87[col_i82];
        let t59 = t88 + t57;
        acc89 += t59;
      }
      arr91.push(acc89);
    }
    arr90.push(arr91);
  }
  return arr90;
}

export function _batch_total_affine(input) {
  let t63 = input["batch"];
  let t75 = input["global_offset"];
  let t76 = 1.0;
  let t57 = t75 + t76;
  let arr94 = [];
  for (let batch_i65 = 0; batch_i65 < t63.length; batch_i65++) {
    let batch_el64 = t63[batch_i65];
    let t66 = batch_el64["row"];
    let arr87 = [];
    for (let row_i68 = 0; row_i68 < t66.length; row_i68++) {
      let row_el67 = t66[row_i68];
      let t69 = row_el67["scale"];
      let t70 = 2.0;
      let t49 = t69 * t70;
      let t71 = row_el67["col"];
      let arr88 = [];
      for (let col_i73 = 0; col_i73 < t71.length; col_i73++) {
        let col_el72 = t71[col_i73];
        let t74 = col_el72["val"];
        let t51 = t74 * t49;
        arr88.push(t51);
      }
      arr87.push(arr88);
    }
    let t79 = batch_el64["mean"];
    let t59 = t79 + t57;
    let t80 = batch_el64["row"];
    let acc93 = 0.0;
    for (let row_i82 = 0; row_i82 < t80.length; row_i82++) {
      let row_el81 = t80[row_i82];
      let t83 = row_el81["col"];
      let acc92 = 0.0;
      for (let col_i85 = 0; col_i85 < t83.length; col_i85++) {
        let col_el84 = t83[col_i85];
        let t90 = arr87[row_i82];
        let t91 = t90[col_i85];
        let t61 = t91 + t59;
        acc92 += t61;
      }
      acc93 += acc92;
    }
    arr94.push(acc93);
  }
  return arr94;
}

