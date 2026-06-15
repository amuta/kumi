export function _t(input) {
  let t5 = input["step"];
  let t2 = parseFloat(t5);
  let t6 = 0.03;
  let t4 = t2 * t6;
  return t4;
}

export function _px(input) {
  let t8 = input["pixels"];
  let arr13 = [];
  for (let pixels_i10 = 0; pixels_i10 < t8.length; pixels_i10++) {
    let pixels_el9 = t8[pixels_i10];
    let t11 = pixels_el9["px"];
    let t12 = t11;
    arr13.push(t12);
  }
  return arr13;
}

export function _lbx(input) {
  let t12 = input["lights"];
  let arr17 = [];
  for (let lights__o_i14 = 0; lights__o_i14 < t12.length; lights__o_i14++) {
    let lights__o_el13 = t12[lights__o_i14];
    let t15 = lights__o_el13["bx"];
    let t16 = t15;
    arr17.push(t16);
  }
  return arr17;
}

export function _lr(input) {
  let t16 = input["lights"];
  let arr21 = [];
  for (let lights__o_i18 = 0; lights__o_i18 < t16.length; lights__o_i18++) {
    let lights__o_el17 = t16[lights__o_i18];
    let t19 = lights__o_el17["r"];
    let t20 = t19;
    arr21.push(t20);
  }
  return arr21;
}

export function _lph(input) {
  let t20 = input["lights"];
  let arr25 = [];
  for (let lights__o_i22 = 0; lights__o_i22 < t20.length; lights__o_i22++) {
    let lights__o_el21 = t20[lights__o_i22];
    let t23 = lights__o_el21["ph"];
    let t24 = t23;
    arr25.push(t24);
  }
  return arr25;
}

export function _lglow(input) {
  let t24 = input["lights"];
  let arr29 = [];
  for (let lights__o_i26 = 0; lights__o_i26 < t24.length; lights__o_i26++) {
    let lights__o_el25 = t24[lights__o_i26];
    let t27 = lights__o_el25["glow"];
    let t28 = t27;
    arr29.push(t28);
  }
  return arr29;
}

export function _lwr(input) {
  let t28 = input["lights"];
  let arr33 = [];
  for (let lights__o_i30 = 0; lights__o_i30 < t28.length; lights__o_i30++) {
    let lights__o_el29 = t28[lights__o_i30];
    let t31 = lights__o_el29["wr"];
    let t32 = t31;
    arr33.push(t32);
  }
  return arr33;
}

export function _lx(input) {
  let t53 = input["step"];
  let t42 = parseFloat(t53);
  let t54 = 0.03;
  let t44 = t42 * t54;
  let t55 = input["lights"];
  let arr61 = [];
  for (let lights__o_i57 = 0; lights__o_i57 < t55.length; lights__o_i57++) {
    let lights__o_el56 = t55[lights__o_i57];
    let t58 = lights__o_el56["ph"];
    let t32 = t44 + t58;
    let t33 = Math.cos(t32);
    let t59 = lights__o_el56["r"];
    let t35 = t33 * t59;
    let t60 = lights__o_el56["bx"];
    let t36 = t60 + t35;
    arr61.push(t36);
  }
  return arr61;
}

export function _dx(input) {
  let t66 = input["step"];
  let t50 = parseFloat(t66);
  let t67 = 0.03;
  let t52 = t50 * t67;
  let t68 = input["lights"];
  let arr81 = [];
  for (let lights__o_i70 = 0; lights__o_i70 < t68.length; lights__o_i70++) {
    let lights__o_el69 = t68[lights__o_i70];
    let t71 = lights__o_el69["ph"];
    let t58 = t52 + t71;
    let t59 = Math.cos(t58);
    let t72 = lights__o_el69["r"];
    let t64 = t59 * t72;
    let t73 = lights__o_el69["bx"];
    let t65 = t73 + t64;
    arr81.push(t65);
  }
  let t74 = input["pixels"];
  let arr83 = [];
  for (let pixels_i76 = 0; pixels_i76 < t74.length; pixels_i76++) {
    let pixels_el75 = t74[pixels_i76];
    let t77 = input["lights"];
    let arr84 = [];
    for (let lights__o_i79 = 0; lights__o_i79 < t77.length; lights__o_i79++) {
      let lights__o_el78 = t77[lights__o_i79];
      let t80 = pixels_el75["px"];
      let t82 = arr81[lights__o_i79];
      let t41 = t80 - t82;
      arr84.push(t41);
    }
    arr83.push(arr84);
  }
  return arr83;
}

export function _intensity(input) {
  let t82 = input["step"];
  let t64 = parseFloat(t82);
  let t83 = 0.03;
  let t66 = t64 * t83;
  let t84 = input["lights"];
  let arr97 = [];
  for (let lights__o_i86 = 0; lights__o_i86 < t84.length; lights__o_i86++) {
    let lights__o_el85 = t84[lights__o_i86];
    let t87 = lights__o_el85["ph"];
    let t72 = t66 + t87;
    let t73 = Math.cos(t72);
    let t88 = lights__o_el85["r"];
    let t78 = t73 * t88;
    let t89 = lights__o_el85["bx"];
    let t79 = t89 + t78;
    arr97.push(t79);
  }
  let t90 = input["pixels"];
  let arr101 = [];
  for (let pixels_i92 = 0; pixels_i92 < t90.length; pixels_i92++) {
    let pixels_el91 = t90[pixels_i92];
    let t93 = input["lights"];
    let arr102 = [];
    for (let lights__o_i95 = 0; lights__o_i95 < t93.length; lights__o_i95++) {
      let lights__o_el94 = t93[lights__o_i95];
      let t96 = pixels_el91["px"];
      let t98 = arr97[lights__o_i95];
      let t81 = t96 - t98;
      let t46 = t81 * t81;
      let t99 = 0.01;
      let t49 = t46 + t99;
      let t100 = lights__o_el94["glow"];
      let t50 = t100 / t49;
      arr102.push(t50);
    }
    arr101.push(arr102);
  }
  return arr101;
}

export function _brightness(input) {
  let t124 = input["step"];
  let t70 = parseFloat(t124);
  let t125 = 0.03;
  let t72 = t70 * t125;
  let t126 = input["lights"];
  let arr139 = [];
  for (let lights__o_i128 = 0; lights__o_i128 < t126.length; lights__o_i128++) {
    let lights__o_el127 = t126[lights__o_i128];
    let t129 = lights__o_el127["ph"];
    let t78 = t72 + t129;
    let t79 = Math.cos(t78);
    let t130 = lights__o_el127["r"];
    let t84 = t79 * t130;
    let t131 = lights__o_el127["bx"];
    let t85 = t131 + t84;
    arr139.push(t85);
  }
  let t132 = input["pixels"];
  let arr145 = [];
  for (let pixels_i134 = 0; pixels_i134 < t132.length; pixels_i134++) {
    let pixels_el133 = t132[pixels_i134];
    let t135 = input["lights"];
    let acc144 = 0.0;
    for (let lights__o_i137 = 0; lights__o_i137 < t135.length; lights__o_i137++) {
      let lights__o_el136 = t135[lights__o_i137];
      let t138 = pixels_el133["px"];
      let t140 = arr139[lights__o_i137];
      let t87 = t138 - t140;
      let t115 = t87 * t87;
      let t141 = 0.01;
      let t118 = t115 + t141;
      let t142 = lights__o_el136["glow"];
      let t119 = t142 / t118;
      let t143 = lights__o_el136["wr"];
      let t54 = t119 * t143;
      acc144 += t54;
    }
    let t55 = acc144;
    arr145.push(t55);
  }
  return arr145;
}

