export function _xi(input) {
  let t4 = input["bodies"];
  let arr9 = [];
  for (let bodies_i6 = 0; bodies_i6 < t4.length; bodies_i6++) {
    let bodies_el5 = t4[bodies_i6];
    let t7 = bodies_el5["x"];
    arr9.push(t7);
  }
  return arr9;
}

export function _xj(input) {
  let t8 = input["bodies"];
  let arr15 = [];
  for (let bodies_i10 = 0; bodies_i10 < t8.length; bodies_i10++) {
    let bodies_el9 = t8[bodies_i10];
    let t11 = input["bodies"];
    let arr16 = [];
    for (let bodies__x_i13 = 0; bodies__x_i13 < t11.length; bodies__x_i13++) {
      let bodies__x_el12 = t11[bodies__x_i13];
      let t14 = bodies__x_el12["x"];
      arr16.push(t14);
    }
    arr15.push(arr16);
  }
  return arr15;
}

export function _mj(input) {
  let t12 = input["bodies"];
  let arr19 = [];
  for (let bodies_i14 = 0; bodies_i14 < t12.length; bodies_i14++) {
    let bodies_el13 = t12[bodies_i14];
    let t15 = input["bodies"];
    let arr20 = [];
    for (let bodies__x_i17 = 0; bodies__x_i17 < t15.length; bodies__x_i17++) {
      let bodies__x_el16 = t15[bodies__x_i17];
      let t18 = bodies__x_el16["m"];
      arr20.push(t18);
    }
    arr19.push(arr20);
  }
  return arr19;
}

export function _dx(input) {
  let t20 = input["bodies"];
  let arr28 = [];
  for (let bodies_i22 = 0; bodies_i22 < t20.length; bodies_i22++) {
    let bodies_el21 = t20[bodies_i22];
    let t23 = input["bodies"];
    let arr29 = [];
    for (let bodies__x_i25 = 0; bodies__x_i25 < t23.length; bodies__x_i25++) {
      let bodies__x_el24 = t23[bodies__x_i25];
      let t26 = bodies__x_el24["x"];
      let t27 = bodies_el21["x"];
      let t15 = t26 - t27;
      arr29.push(t15);
    }
    arr28.push(arr29);
  }
  return arr28;
}

export function _dist(input) {
  let t30 = input["bodies"];
  let arr39 = [];
  for (let bodies_i32 = 0; bodies_i32 < t30.length; bodies_i32++) {
    let bodies_el31 = t30[bodies_i32];
    let t33 = input["bodies"];
    let arr40 = [];
    for (let bodies__x_i35 = 0; bodies__x_i35 < t33.length; bodies__x_i35++) {
      let bodies__x_el34 = t33[bodies__x_i35];
      let t36 = bodies__x_el34["x"];
      let t37 = bodies_el31["x"];
      let t29 = t36 - t37;
      let t17 = Math.abs(t29);
      let t38 = input["eps"];
      let t20 = t17 + t38;
      arr40.push(t20);
    }
    arr39.push(arr40);
  }
  return arr39;
}

export function _accel(input) {
  let t57 = input["bodies"];
  let arr68 = [];
  for (let bodies_i59 = 0; bodies_i59 < t57.length; bodies_i59++) {
    let bodies_el58 = t57[bodies_i59];
    let t60 = input["bodies"];
    let acc67 = 0.0;
    for (let bodies__x_i62 = 0; bodies__x_i62 < t60.length; bodies__x_i62++) {
      let bodies__x_el61 = t60[bodies__x_i62];
      let t63 = bodies__x_el61["m"];
      let t64 = bodies__x_el61["x"];
      let t65 = bodies_el58["x"];
      let t43 = t64 - t65;
      let t23 = t63 * t43;
      let t53 = Math.abs(t43);
      let t66 = input["eps"];
      let t56 = t53 + t66;
      let t26 = t56 * t56;
      let t28 = t26 * t56;
      let t29 = t23 / t28;
      acc67 += t29;
    }
    arr68.push(acc67);
  }
  return arr68;
}

