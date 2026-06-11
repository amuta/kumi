export function _high_performer(input) {
  let t13 = input["regions"];
  let arr27 = [];
  for (let regions_i15 = 0; regions_i15 < t13.length; regions_i15++) {
    let regions_el14 = t13[regions_i15];
    let t16 = regions_el14["offices"];
    let arr28 = [];
    for (let offices_i18 = 0; offices_i18 < t16.length; offices_i18++) {
      let offices_el17 = t16[offices_i18];
      let t19 = offices_el17["teams"];
      let arr29 = [];
      for (let teams_i21 = 0; teams_i21 < t19.length; teams_i21++) {
        let teams_el20 = t19[teams_i21];
        let t22 = teams_el20["employees"];
        let arr30 = [];
        for (let employees_i24 = 0; employees_i24 < t22.length; employees_i24++) {
          let employees_el23 = t22[employees_i24];
          let t25 = employees_el23["rating"];
          let t26 = 4.5;
          let t12 = t25 >= t26;
          arr30.push(t12);
        }
        arr29.push(arr30);
      }
      arr28.push(arr29);
    }
    arr27.push(arr28);
  }
  return arr27;
}

export function _senior_level(input) {
  let t25 = input["regions"];
  let arr39 = [];
  for (let regions_i27 = 0; regions_i27 < t25.length; regions_i27++) {
    let regions_el26 = t25[regions_i27];
    let t28 = regions_el26["offices"];
    let arr40 = [];
    for (let offices_i30 = 0; offices_i30 < t28.length; offices_i30++) {
      let offices_el29 = t28[offices_i30];
      let t31 = offices_el29["teams"];
      let arr41 = [];
      for (let teams_i33 = 0; teams_i33 < t31.length; teams_i33++) {
        let teams_el32 = t31[teams_i33];
        let t34 = teams_el32["employees"];
        let arr42 = [];
        for (let employees_i36 = 0; employees_i36 < t34.length; employees_i36++) {
          let employees_el35 = t34[employees_i36];
          let t37 = employees_el35["level"];
          let t38 = "senior";
          let t24 = t37 == t38;
          arr42.push(t24);
        }
        arr41.push(arr42);
      }
      arr40.push(arr41);
    }
    arr39.push(arr40);
  }
  return arr39;
}

export function _top_team(input) {
  let t35 = input["regions"];
  let arr46 = [];
  for (let regions_i37 = 0; regions_i37 < t35.length; regions_i37++) {
    let regions_el36 = t35[regions_i37];
    let t38 = regions_el36["offices"];
    let arr47 = [];
    for (let offices_i40 = 0; offices_i40 < t38.length; offices_i40++) {
      let offices_el39 = t38[offices_i40];
      let t41 = offices_el39["teams"];
      let arr48 = [];
      for (let teams_i43 = 0; teams_i43 < t41.length; teams_i43++) {
        let teams_el42 = t41[teams_i43];
        let t44 = teams_el42["performance_score"];
        let t45 = 0.9;
        let t34 = t44 >= t45;
        arr48.push(t34);
      }
      arr47.push(arr48);
    }
    arr46.push(arr47);
  }
  return arr46;
}

export function _employee_bonus(input) {
  let t117 = input["regions"];
  let arr137 = [];
  let arr142 = [];
  let arr151 = [];
  for (let regions_i119 = 0; regions_i119 < t117.length; regions_i119++) {
    let regions_el118 = t117[regions_i119];
    let t120 = regions_el118["offices"];
    let arr138 = [];
    let arr143 = [];
    let arr152 = [];
    for (let offices_i122 = 0; offices_i122 < t120.length; offices_i122++) {
      let offices_el121 = t120[offices_i122];
      let t123 = offices_el121["teams"];
      let arr139 = [];
      let arr144 = [];
      let arr153 = [];
      for (let teams_i125 = 0; teams_i125 < t123.length; teams_i125++) {
        let teams_el124 = t123[teams_i125];
        let t126 = teams_el124["employees"];
        let arr140 = [];
        let arr145 = [];
        for (let employees_i128 = 0; employees_i128 < t126.length; employees_i128++) {
          let employees_el127 = t126[employees_i128];
          let t129 = employees_el127["rating"];
          let t130 = 4.5;
          let t94 = t129 >= t130;
          arr145.push(t94);
          let t131 = employees_el127["level"];
          let t132 = "senior";
          let t106 = t131 == t132;
          arr140.push(t106);
        }
        arr144.push(arr145);
        arr139.push(arr140);
        let t133 = teams_el124["performance_score"];
        let t134 = 0.9;
        let t116 = t133 >= t134;
        let arr154 = [];
        for (let employees_i136 = 0; employees_i136 < t126.length; employees_i136++) {
          let employees_el135 = t126[employees_i136];
          let t141 = arr140[employees_i136];
          let t39 = t141 && t116;
          let t146 = arr145[employees_i136];
          let t40 = t146 && t39;
          let t147 = employees_el135["salary"];
          let t148 = 0.3;
          let t52 = t147 * t148;
          let t56 = t146 && t116;
          let t149 = 0.2;
          let t68 = t147 * t149;
          let t150 = 0.05;
          let t80 = t147 * t150;
          let t81 = t56 ? t68 : t80;
          let t82 = t40 ? t52 : t81;
          arr154.push(t82);
        }
        arr153.push(arr154);
      }
      arr152.push(arr153);
      arr143.push(arr144);
      arr138.push(arr139);
    }
    arr151.push(arr152);
    arr142.push(arr143);
    arr137.push(arr138);
  }
  return arr151;
}

