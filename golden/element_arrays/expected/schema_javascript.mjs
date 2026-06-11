export function _cube(input) {
  let t2 = input["cube"];
  return t2;
}

export function _layer(input) {
  let t4 = input["cube"];
  let arr8 = [];
  for (let cube_i6 = 0; cube_i6 < t4.length; cube_i6++) {
    let cube_el5 = t4[cube_i6];
    let t7 = cube_el5;
    arr8.push(t7);
  }
  return arr8;
}

export function _row(input) {
  let t7 = input["cube"];
  let arr13 = [];
  for (let cube_i9 = 0; cube_i9 < t7.length; cube_i9++) {
    let cube_el8 = t7[cube_i9];
    let arr14 = [];
    for (let layer_i11 = 0; layer_i11 < cube_el8.length; layer_i11++) {
      let layer_el10 = cube_el8[layer_i11];
      let t12 = layer_el10;
      arr14.push(t12);
    }
    arr13.push(arr14);
  }
  return arr13;
}

export function _cell(input) {
  let t11 = input["cube"];
  let arr19 = [];
  for (let cube_i13 = 0; cube_i13 < t11.length; cube_i13++) {
    let cube_el12 = t11[cube_i13];
    let arr20 = [];
    for (let layer_i15 = 0; layer_i15 < cube_el12.length; layer_i15++) {
      let layer_el14 = cube_el12[layer_i15];
      let arr21 = [];
      for (let row_i17 = 0; row_i17 < layer_el14.length; row_i17++) {
        let row_el16 = layer_el14[row_i17];
        let t18 = row_el16;
        arr21.push(t18);
      }
      arr20.push(arr21);
    }
    arr19.push(arr20);
  }
  return arr19;
}

export function _cell_over_limit(input) {
  let t18 = input["cube"];
  let arr26 = [];
  for (let cube_i20 = 0; cube_i20 < t18.length; cube_i20++) {
    let cube_el19 = t18[cube_i20];
    let arr27 = [];
    for (let layer_i22 = 0; layer_i22 < cube_el19.length; layer_i22++) {
      let layer_el21 = cube_el19[layer_i22];
      let arr28 = [];
      for (let row_i24 = 0; row_i24 < layer_el21.length; row_i24++) {
        let row_el23 = layer_el21[row_i24];
        let t25 = 100;
        let t17 = row_el23 > t25;
        arr28.push(t17);
      }
      arr27.push(arr28);
    }
    arr26.push(arr27);
  }
  return arr26;
}

export function _cell_sum(input) {
  let t34 = input["cube"];
  let arr44 = [];
  for (let cube_i36 = 0; cube_i36 < t34.length; cube_i36++) {
    let cube_el35 = t34[cube_i36];
    let arr45 = [];
    for (let layer_i38 = 0; layer_i38 < cube_el35.length; layer_i38++) {
      let layer_el37 = cube_el35[layer_i38];
      let acc43 = 0;
      for (let row_i40 = 0; row_i40 < layer_el37.length; row_i40++) {
        let row_el39 = layer_el37[row_i40];
        let t41 = 100;
        let t33 = row_el39 > t41;
        let t42 = 0;
        let t25 = t33 ? row_el39 : t42;
        acc43 += t25;
      }
      let t26 = acc43;
      arr45.push(t26);
    }
    arr44.push(arr45);
  }
  return arr44;
}

export function _count_over_limit(input) {
  let t43 = input["cube"];
  let acc55 = 0;
  for (let cube_i45 = 0; cube_i45 < t43.length; cube_i45++) {
    let cube_el44 = t43[cube_i45];
    let acc54 = 0;
    for (let layer_i47 = 0; layer_i47 < cube_el44.length; layer_i47++) {
      let layer_el46 = cube_el44[layer_i47];
      let acc53 = 0;
      for (let row_i49 = 0; row_i49 < layer_el46.length; row_i49++) {
        let row_el48 = layer_el46[row_i49];
        let t50 = 100;
        let t42 = row_el48 > t50;
        let t51 = 1;
        let t52 = 0;
        let t32 = t42 ? t51 : t52;
        acc53 += t32;
      }
      let t33 = acc53;
      acc54 += t33;
    }
    let t34 = acc54;
    acc55 += t34;
  }
  let t35 = acc55;
  return t35;
}

