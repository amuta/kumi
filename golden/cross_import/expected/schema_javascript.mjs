export function _result(input) {
  let t9 = input["vals"];
  let arr18 = [];
  for (let vals_i11 = 0; vals_i11 < t9.length; vals_i11++) {
    let vals_el10 = t9[vals_i11];
    let t12 = input["vals"];
    let acc17 = 0.0;
    for (let vals__x_i14 = 0; vals__x_i14 < t12.length; vals__x_i14++) {
      let vals__x_el13 = t12[vals__x_i14];
      let t15 = vals__x_el13["a"];
      let t5 = t15;
      let t16 = vals_el10["a"];
      let t7 = t5 - t16;
      acc17 += t7;
    }
    let t8 = acc17;
    arr18.push(t8);
  }
  return arr18;
}

