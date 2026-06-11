export function _region_max(input) {
  let t7 = input["regions"];
  let arr15 = [];
  for (let regions_i9 = 0; regions_i9 < t7.length; regions_i9++) {
    let regions_el8 = t7[regions_i9];
    let t10 = regions_el8["sales"];
    let acc14 = null;
    for (let sales_i12 = 0; sales_i12 < t10.length; sales_i12++) {
      let sales_el11 = t10[sales_i12];
      let t13 = sales_el11["amount"];
      acc14 = (t13 !== null && (acc14 === null || t13 > acc14)) ? t13 : acc14;
    }
    let t6 = acc14;
    arr15.push(t6);
  }
  return arr15;
}

export function _region_min(input) {
  let t13 = input["regions"];
  let arr21 = [];
  for (let regions_i15 = 0; regions_i15 < t13.length; regions_i15++) {
    let regions_el14 = t13[regions_i15];
    let t16 = regions_el14["sales"];
    let acc20 = null;
    for (let sales_i18 = 0; sales_i18 < t16.length; sales_i18++) {
      let sales_el17 = t16[sales_i18];
      let t19 = sales_el17["amount"];
      acc20 = (t19 !== null && (acc20 === null || t19 < acc20)) ? t19 : acc20;
    }
    let t12 = acc20;
    arr21.push(t12);
  }
  return arr21;
}

export function _region_labels(input) {
  let t19 = input["regions"];
  let arr27 = [];
  for (let regions_i21 = 0; regions_i21 < t19.length; regions_i21++) {
    let regions_el20 = t19[regions_i21];
    let t22 = regions_el20["tags"];
    let acc26 = "";
    for (let tags_i24 = 0; tags_i24 < t22.length; tags_i24++) {
      let tags_el23 = t22[tags_i24];
      let t25 = tags_el23["label"];
      acc26 += t25;
    }
    let t18 = acc26;
    arr27.push(t18);
  }
  return arr27;
}

export function _best_region_sale(input) {
  let t27 = input["regions"];
  let acc35 = null;
  for (let regions_i29 = 0; regions_i29 < t27.length; regions_i29++) {
    let regions_el28 = t27[regions_i29];
    let t30 = regions_el28["sales"];
    let acc34 = null;
    for (let sales_i32 = 0; sales_i32 < t30.length; sales_i32++) {
      let sales_el31 = t30[sales_i32];
      let t33 = sales_el31["amount"];
      acc34 = (t33 !== null && (acc34 === null || t33 > acc34)) ? t33 : acc34;
    }
    let t26 = acc34;
    acc35 = (t26 !== null && (acc35 === null || t26 > acc35)) ? t26 : acc35;
  }
  let t20 = acc35;
  return t20;
}

export function _worst_region_sale(input) {
  let t29 = input["regions"];
  let acc37 = null;
  for (let regions_i31 = 0; regions_i31 < t29.length; regions_i31++) {
    let regions_el30 = t29[regions_i31];
    let t32 = regions_el30["sales"];
    let acc36 = null;
    for (let sales_i34 = 0; sales_i34 < t32.length; sales_i34++) {
      let sales_el33 = t32[sales_i34];
      let t35 = sales_el33["amount"];
      acc36 = (t35 !== null && (acc36 === null || t35 < acc36)) ? t35 : acc36;
    }
    let t28 = acc36;
    acc37 = (t28 !== null && (acc37 === null || t28 < acc37)) ? t28 : acc37;
  }
  let t22 = acc37;
  return t22;
}

