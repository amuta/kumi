export function _a(input) {
  let t4 = input["rows"];
  let arr10 = [];
  for (let rows_i6 = 0; rows_i6 < t4.length; rows_i6++) {
    let rows_el5 = t4[rows_i6];
    let arr11 = [];
    for (let col_i8 = 0; col_i8 < rows_el5.length; col_i8++) {
      let col_el7 = rows_el5[col_i8];
      let t9 = col_el7;
      arr11.push(t9);
    }
    arr10.push(arr11);
  }
  return arr10;
}

export function _n(input) {
  let t9 = input["rows"];
  let arr20 = [];
  for (let rows_i11 = 0; rows_i11 < t9.length; rows_i11++) {
    let rows_el10 = t9[rows_i11];
    let arr21 = [];
    for (let col_i13 = 0; col_i13 < rows_el10.length; col_i13++) {
      let col_el12 = rows_el10[col_i13];
      let t14 = input["rows"];
      let t15 = t14.length;
      let t16 = t14[Math.min(Math.max(rows_i11 - (-1), 0), t15 - 1)];
      let t17 = t16[col_i13];
      let t18_j = rows_i11 - (-1);
      let t18 = t18_j >= 0 && t18_j < t15;
      let t19 = 0;
      let t4 = t18 ? t17 : t19;
      arr21.push(t4);
    }
    arr20.push(arr21);
  }
  return arr20;
}

export function _s(input) {
  let t11 = input["rows"];
  let arr22 = [];
  for (let rows_i13 = 0; rows_i13 < t11.length; rows_i13++) {
    let rows_el12 = t11[rows_i13];
    let arr23 = [];
    for (let col_i15 = 0; col_i15 < rows_el12.length; col_i15++) {
      let col_el14 = rows_el12[col_i15];
      let t16 = input["rows"];
      let t17 = t16.length;
      let t18 = t16[Math.min(Math.max(rows_i13 - (1), 0), t17 - 1)];
      let t19 = t18[col_i15];
      let t20_j = rows_i13 - (1);
      let t20 = t20_j >= 0 && t20_j < t17;
      let t21 = 0;
      let t6 = t20 ? t19 : t21;
      arr23.push(t6);
    }
    arr22.push(arr23);
  }
  return arr22;
}

export function _w(input) {
  let t13 = input["rows"];
  let arr22 = [];
  for (let rows_i15 = 0; rows_i15 < t13.length; rows_i15++) {
    let rows_el14 = t13[rows_i15];
    let arr23 = [];
    for (let col_i17 = 0; col_i17 < rows_el14.length; col_i17++) {
      let col_el16 = rows_el14[col_i17];
      let t18 = rows_el14.length;
      let t19 = rows_el14[Math.min(Math.max(col_i17 - (-1), 0), t18 - 1)];
      let t20_j = col_i17 - (-1);
      let t20 = t20_j >= 0 && t20_j < t18;
      let t21 = 0;
      let t8 = t20 ? t19 : t21;
      arr23.push(t8);
    }
    arr22.push(arr23);
  }
  return arr22;
}

export function _e(input) {
  let t15 = input["rows"];
  let arr24 = [];
  for (let rows_i17 = 0; rows_i17 < t15.length; rows_i17++) {
    let rows_el16 = t15[rows_i17];
    let arr25 = [];
    for (let col_i19 = 0; col_i19 < rows_el16.length; col_i19++) {
      let col_el18 = rows_el16[col_i19];
      let t20 = rows_el16.length;
      let t21 = rows_el16[Math.min(Math.max(col_i19 - (1), 0), t20 - 1)];
      let t22_j = col_i19 - (1);
      let t22 = t22_j >= 0 && t22_j < t20;
      let t23 = 0;
      let t10 = t22 ? t21 : t23;
      arr25.push(t10);
    }
    arr24.push(arr25);
  }
  return arr24;
}

export function _nw(input) {
  let t18 = input["rows"];
  let arr37 = [];
  for (let rows_i20 = 0; rows_i20 < t18.length; rows_i20++) {
    let rows_el19 = t18[rows_i20];
    let arr30 = [];
    for (let col_i22 = 0; col_i22 < rows_el19.length; col_i22++) {
      let col_el21 = rows_el19[col_i22];
      let t23 = input["rows"];
      let t24 = t23.length;
      let t25 = t23[Math.min(Math.max(rows_i20 - (-1), 0), t24 - 1)];
      let t26 = t25[col_i22];
      let t27_j = rows_i20 - (-1);
      let t27 = t27_j >= 0 && t27_j < t24;
      let t28 = 0;
      let t17 = t27 ? t26 : t28;
      arr30.push(t17);
    }
    let arr38 = [];
    for (let col_i32 = 0; col_i32 < rows_el19.length; col_i32++) {
      let col_el31 = rows_el19[col_i32];
      let t33 = arr30.length;
      let t34 = arr30[Math.min(Math.max(col_i32 - (-1), 0), t33 - 1)];
      let t35_j = col_i32 - (-1);
      let t35 = t35_j >= 0 && t35_j < t33;
      let t36 = 0;
      let t12 = t35 ? t34 : t36;
      arr38.push(t12);
    }
    arr37.push(arr38);
  }
  return arr37;
}

export function _ne(input) {
  let t20 = input["rows"];
  let arr39 = [];
  for (let rows_i22 = 0; rows_i22 < t20.length; rows_i22++) {
    let rows_el21 = t20[rows_i22];
    let arr32 = [];
    for (let col_i24 = 0; col_i24 < rows_el21.length; col_i24++) {
      let col_el23 = rows_el21[col_i24];
      let t25 = input["rows"];
      let t26 = t25.length;
      let t27 = t25[Math.min(Math.max(rows_i22 - (-1), 0), t26 - 1)];
      let t28 = t27[col_i24];
      let t29_j = rows_i22 - (-1);
      let t29 = t29_j >= 0 && t29_j < t26;
      let t30 = 0;
      let t19 = t29 ? t28 : t30;
      arr32.push(t19);
    }
    let arr40 = [];
    for (let col_i34 = 0; col_i34 < rows_el21.length; col_i34++) {
      let col_el33 = rows_el21[col_i34];
      let t35 = arr32.length;
      let t36 = arr32[Math.min(Math.max(col_i34 - (1), 0), t35 - 1)];
      let t37_j = col_i34 - (1);
      let t37 = t37_j >= 0 && t37_j < t35;
      let t38 = 0;
      let t14 = t37 ? t36 : t38;
      arr40.push(t14);
    }
    arr39.push(arr40);
  }
  return arr39;
}

export function _sw(input) {
  let t22 = input["rows"];
  let arr41 = [];
  for (let rows_i24 = 0; rows_i24 < t22.length; rows_i24++) {
    let rows_el23 = t22[rows_i24];
    let arr34 = [];
    for (let col_i26 = 0; col_i26 < rows_el23.length; col_i26++) {
      let col_el25 = rows_el23[col_i26];
      let t27 = input["rows"];
      let t28 = t27.length;
      let t29 = t27[Math.min(Math.max(rows_i24 - (1), 0), t28 - 1)];
      let t30 = t29[col_i26];
      let t31_j = rows_i24 - (1);
      let t31 = t31_j >= 0 && t31_j < t28;
      let t32 = 0;
      let t21 = t31 ? t30 : t32;
      arr34.push(t21);
    }
    let arr42 = [];
    for (let col_i36 = 0; col_i36 < rows_el23.length; col_i36++) {
      let col_el35 = rows_el23[col_i36];
      let t37 = arr34.length;
      let t38 = arr34[Math.min(Math.max(col_i36 - (-1), 0), t37 - 1)];
      let t39_j = col_i36 - (-1);
      let t39 = t39_j >= 0 && t39_j < t37;
      let t40 = 0;
      let t16 = t39 ? t38 : t40;
      arr42.push(t16);
    }
    arr41.push(arr42);
  }
  return arr41;
}

export function _se(input) {
  let t24 = input["rows"];
  let arr43 = [];
  for (let rows_i26 = 0; rows_i26 < t24.length; rows_i26++) {
    let rows_el25 = t24[rows_i26];
    let arr36 = [];
    for (let col_i28 = 0; col_i28 < rows_el25.length; col_i28++) {
      let col_el27 = rows_el25[col_i28];
      let t29 = input["rows"];
      let t30 = t29.length;
      let t31 = t29[Math.min(Math.max(rows_i26 - (1), 0), t30 - 1)];
      let t32 = t31[col_i28];
      let t33_j = rows_i26 - (1);
      let t33 = t33_j >= 0 && t33_j < t30;
      let t34 = 0;
      let t23 = t33 ? t32 : t34;
      arr36.push(t23);
    }
    let arr44 = [];
    for (let col_i38 = 0; col_i38 < rows_el25.length; col_i38++) {
      let col_el37 = rows_el25[col_i38];
      let t39 = arr36.length;
      let t40 = arr36[Math.min(Math.max(col_i38 - (1), 0), t39 - 1)];
      let t41_j = col_i38 - (1);
      let t41 = t41_j >= 0 && t41_j < t39;
      let t42 = 0;
      let t18 = t41 ? t40 : t42;
      arr44.push(t18);
    }
    arr43.push(arr44);
  }
  return arr43;
}

export function _neighbors(input) {
  let t66 = input["rows"];
  let arr116 = [];
  for (let rows_i68 = 0; rows_i68 < t66.length; rows_i68++) {
    let rows_el67 = t66[rows_i68];
    let arr89 = [];
    let arr100 = [];
    let arr111 = [];
    let arr114 = [];
    for (let col_i70 = 0; col_i70 < rows_el67.length; col_i70++) {
      let col_el69 = rows_el67[col_i70];
      let t71 = input["rows"];
      let t72 = t71.length;
      let t73 = t71[Math.min(Math.max(rows_i68 - (-1), 0), t72 - 1)];
      let t74 = t73[col_i70];
      let t75_j = rows_i68 - (-1);
      let t75 = t75_j >= 0 && t75_j < t72;
      let t76 = 0;
      let t33 = t75 ? t74 : t76;
      arr89.push(t33);
      let t77 = t71[Math.min(Math.max(rows_i68 - (1), 0), t72 - 1)];
      let t78 = t77[col_i70];
      let t79_j = rows_i68 - (1);
      let t79 = t79_j >= 0 && t79_j < t72;
      let t80 = 0;
      let t37 = t79 ? t78 : t80;
      arr100.push(t37);
      let t81 = rows_el67.length;
      let t82 = rows_el67[Math.min(Math.max(col_i70 - (-1), 0), t81 - 1)];
      let t83_j = col_i70 - (-1);
      let t83 = t83_j >= 0 && t83_j < t81;
      let t84 = 0;
      let t41 = t83 ? t82 : t84;
      arr111.push(t41);
      let t85 = rows_el67[Math.min(Math.max(col_i70 - (1), 0), t81 - 1)];
      let t86_j = col_i70 - (1);
      let t86 = t86_j >= 0 && t86_j < t81;
      let t87 = 0;
      let t45 = t86 ? t85 : t87;
      arr114.push(t45);
    }
    let arr117 = [];
    for (let col_i91 = 0; col_i91 < rows_el67.length; col_i91++) {
      let col_el90 = rows_el67[col_i91];
      let t92 = arr89.length;
      let t93 = arr89[Math.min(Math.max(col_i91 - (-1), 0), t92 - 1)];
      let t94_j = col_i91 - (-1);
      let t94 = t94_j >= 0 && t94_j < t92;
      let t95 = 0;
      let t50 = t94 ? t93 : t95;
      let t96 = arr89[Math.min(Math.max(col_i91 - (1), 0), t92 - 1)];
      let t97_j = col_i91 - (1);
      let t97 = t97_j >= 0 && t97_j < t92;
      let t98 = 0;
      let t55 = t97 ? t96 : t98;
      let t101 = arr100.length;
      let t102 = arr100[Math.min(Math.max(col_i91 - (-1), 0), t101 - 1)];
      let t103_j = col_i91 - (-1);
      let t103 = t103_j >= 0 && t103_j < t101;
      let t104 = 0;
      let t60 = t103 ? t102 : t104;
      let t105 = arr100[Math.min(Math.max(col_i91 - (1), 0), t101 - 1)];
      let t106_j = col_i91 - (1);
      let t106 = t106_j >= 0 && t106_j < t101;
      let t107 = 0;
      let t65 = t106 ? t105 : t107;
      let t108 = arr89[col_i91];
      let t109 = arr100[col_i91];
      let acc0 = t108 + t109;
      let t112 = arr111[col_i91];
      let acc1 = acc0 + t112;
      let t115 = arr114[col_i91];
      let acc2 = acc1 + t115;
      let acc3 = acc2 + t50;
      let acc4 = acc3 + t55;
      let acc5 = acc4 + t60;
      let acc6 = acc5 + t65;
      arr117.push(acc6);
    }
    arr116.push(arr117);
  }
  return arr116;
}

export function _alive(input) {
  let t37 = input["rows"];
  let arr43 = [];
  for (let rows_i39 = 0; rows_i39 < t37.length; rows_i39++) {
    let rows_el38 = t37[rows_i39];
    let arr44 = [];
    for (let col_i41 = 0; col_i41 < rows_el38.length; col_i41++) {
      let col_el40 = rows_el38[col_i41];
      let t42 = 0;
      let t33 = col_el40 > t42;
      arr44.push(t33);
    }
    arr43.push(arr44);
  }
  return arr43;
}

export function _n3_alive(input) {
  let t74 = input["rows"];
  let arr125 = [];
  for (let rows_i76 = 0; rows_i76 < t74.length; rows_i76++) {
    let rows_el75 = t74[rows_i76];
    let arr97 = [];
    let arr108 = [];
    let arr119 = [];
    let arr122 = [];
    for (let col_i78 = 0; col_i78 < rows_el75.length; col_i78++) {
      let col_el77 = rows_el75[col_i78];
      let t79 = input["rows"];
      let t80 = t79.length;
      let t81 = t79[Math.min(Math.max(rows_i76 - (-1), 0), t80 - 1)];
      let t82 = t81[col_i78];
      let t83_j = rows_i76 - (-1);
      let t83 = t83_j >= 0 && t83_j < t80;
      let t84 = 0;
      let t41 = t83 ? t82 : t84;
      arr97.push(t41);
      let t85 = t79[Math.min(Math.max(rows_i76 - (1), 0), t80 - 1)];
      let t86 = t85[col_i78];
      let t87_j = rows_i76 - (1);
      let t87 = t87_j >= 0 && t87_j < t80;
      let t88 = 0;
      let t45 = t87 ? t86 : t88;
      arr108.push(t45);
      let t89 = rows_el75.length;
      let t90 = rows_el75[Math.min(Math.max(col_i78 - (-1), 0), t89 - 1)];
      let t91_j = col_i78 - (-1);
      let t91 = t91_j >= 0 && t91_j < t89;
      let t92 = 0;
      let t49 = t91 ? t90 : t92;
      arr119.push(t49);
      let t93 = rows_el75[Math.min(Math.max(col_i78 - (1), 0), t89 - 1)];
      let t94_j = col_i78 - (1);
      let t94 = t94_j >= 0 && t94_j < t89;
      let t95 = 0;
      let t53 = t94 ? t93 : t95;
      arr122.push(t53);
    }
    let arr126 = [];
    for (let col_i99 = 0; col_i99 < rows_el75.length; col_i99++) {
      let col_el98 = rows_el75[col_i99];
      let t100 = arr97.length;
      let t101 = arr97[Math.min(Math.max(col_i99 - (-1), 0), t100 - 1)];
      let t102_j = col_i99 - (-1);
      let t102 = t102_j >= 0 && t102_j < t100;
      let t103 = 0;
      let t58 = t102 ? t101 : t103;
      let t104 = arr97[Math.min(Math.max(col_i99 - (1), 0), t100 - 1)];
      let t105_j = col_i99 - (1);
      let t105 = t105_j >= 0 && t105_j < t100;
      let t106 = 0;
      let t63 = t105 ? t104 : t106;
      let t109 = arr108.length;
      let t110 = arr108[Math.min(Math.max(col_i99 - (-1), 0), t109 - 1)];
      let t111_j = col_i99 - (-1);
      let t111 = t111_j >= 0 && t111_j < t109;
      let t112 = 0;
      let t68 = t111 ? t110 : t112;
      let t113 = arr108[Math.min(Math.max(col_i99 - (1), 0), t109 - 1)];
      let t114_j = col_i99 - (1);
      let t114 = t114_j >= 0 && t114_j < t109;
      let t115 = 0;
      let t73 = t114 ? t113 : t115;
      let t116 = arr97[col_i99];
      let t117 = arr108[col_i99];
      let acc0 = t116 + t117;
      let t120 = arr119[col_i99];
      let acc1 = acc0 + t120;
      let t123 = arr122[col_i99];
      let acc2 = acc1 + t123;
      let acc3 = acc2 + t58;
      let acc4 = acc3 + t63;
      let acc5 = acc4 + t68;
      let acc6 = acc5 + t73;
      let t124 = 3;
      let t37 = acc6 == t124;
      arr126.push(t37);
    }
    arr125.push(arr126);
  }
  return arr125;
}

export function _n2_alive(input) {
  let t78 = input["rows"];
  let arr129 = [];
  for (let rows_i80 = 0; rows_i80 < t78.length; rows_i80++) {
    let rows_el79 = t78[rows_i80];
    let arr101 = [];
    let arr112 = [];
    let arr123 = [];
    let arr126 = [];
    for (let col_i82 = 0; col_i82 < rows_el79.length; col_i82++) {
      let col_el81 = rows_el79[col_i82];
      let t83 = input["rows"];
      let t84 = t83.length;
      let t85 = t83[Math.min(Math.max(rows_i80 - (-1), 0), t84 - 1)];
      let t86 = t85[col_i82];
      let t87_j = rows_i80 - (-1);
      let t87 = t87_j >= 0 && t87_j < t84;
      let t88 = 0;
      let t45 = t87 ? t86 : t88;
      arr101.push(t45);
      let t89 = t83[Math.min(Math.max(rows_i80 - (1), 0), t84 - 1)];
      let t90 = t89[col_i82];
      let t91_j = rows_i80 - (1);
      let t91 = t91_j >= 0 && t91_j < t84;
      let t92 = 0;
      let t49 = t91 ? t90 : t92;
      arr112.push(t49);
      let t93 = rows_el79.length;
      let t94 = rows_el79[Math.min(Math.max(col_i82 - (-1), 0), t93 - 1)];
      let t95_j = col_i82 - (-1);
      let t95 = t95_j >= 0 && t95_j < t93;
      let t96 = 0;
      let t53 = t95 ? t94 : t96;
      arr123.push(t53);
      let t97 = rows_el79[Math.min(Math.max(col_i82 - (1), 0), t93 - 1)];
      let t98_j = col_i82 - (1);
      let t98 = t98_j >= 0 && t98_j < t93;
      let t99 = 0;
      let t57 = t98 ? t97 : t99;
      arr126.push(t57);
    }
    let arr130 = [];
    for (let col_i103 = 0; col_i103 < rows_el79.length; col_i103++) {
      let col_el102 = rows_el79[col_i103];
      let t104 = arr101.length;
      let t105 = arr101[Math.min(Math.max(col_i103 - (-1), 0), t104 - 1)];
      let t106_j = col_i103 - (-1);
      let t106 = t106_j >= 0 && t106_j < t104;
      let t107 = 0;
      let t62 = t106 ? t105 : t107;
      let t108 = arr101[Math.min(Math.max(col_i103 - (1), 0), t104 - 1)];
      let t109_j = col_i103 - (1);
      let t109 = t109_j >= 0 && t109_j < t104;
      let t110 = 0;
      let t67 = t109 ? t108 : t110;
      let t113 = arr112.length;
      let t114 = arr112[Math.min(Math.max(col_i103 - (-1), 0), t113 - 1)];
      let t115_j = col_i103 - (-1);
      let t115 = t115_j >= 0 && t115_j < t113;
      let t116 = 0;
      let t72 = t115 ? t114 : t116;
      let t117 = arr112[Math.min(Math.max(col_i103 - (1), 0), t113 - 1)];
      let t118_j = col_i103 - (1);
      let t118 = t118_j >= 0 && t118_j < t113;
      let t119 = 0;
      let t77 = t118 ? t117 : t119;
      let t120 = arr101[col_i103];
      let t121 = arr112[col_i103];
      let acc0 = t120 + t121;
      let t124 = arr123[col_i103];
      let acc1 = acc0 + t124;
      let t127 = arr126[col_i103];
      let acc2 = acc1 + t127;
      let acc3 = acc2 + t62;
      let acc4 = acc3 + t67;
      let acc5 = acc4 + t72;
      let acc6 = acc5 + t77;
      let t128 = 2;
      let t41 = acc6 == t128;
      arr130.push(t41);
    }
    arr129.push(arr130);
  }
  return arr129;
}

export function _keep_alive(input) {
  let t92 = input["rows"];
  let arr144 = [];
  for (let rows_i94 = 0; rows_i94 < t92.length; rows_i94++) {
    let rows_el93 = t92[rows_i94];
    let arr115 = [];
    let arr126 = [];
    let arr137 = [];
    let arr140 = [];
    for (let col_i96 = 0; col_i96 < rows_el93.length; col_i96++) {
      let col_el95 = rows_el93[col_i96];
      let t97 = input["rows"];
      let t98 = t97.length;
      let t99 = t97[Math.min(Math.max(rows_i94 - (-1), 0), t98 - 1)];
      let t100 = t99[col_i96];
      let t101_j = rows_i94 - (-1);
      let t101 = t101_j >= 0 && t101_j < t98;
      let t102 = 0;
      let t48 = t101 ? t100 : t102;
      arr115.push(t48);
      let t103 = t97[Math.min(Math.max(rows_i94 - (1), 0), t98 - 1)];
      let t104 = t103[col_i96];
      let t105_j = rows_i94 - (1);
      let t105 = t105_j >= 0 && t105_j < t98;
      let t106 = 0;
      let t52 = t105 ? t104 : t106;
      arr126.push(t52);
      let t107 = rows_el93.length;
      let t108 = rows_el93[Math.min(Math.max(col_i96 - (-1), 0), t107 - 1)];
      let t109_j = col_i96 - (-1);
      let t109 = t109_j >= 0 && t109_j < t107;
      let t110 = 0;
      let t56 = t109 ? t108 : t110;
      arr137.push(t56);
      let t111 = rows_el93[Math.min(Math.max(col_i96 - (1), 0), t107 - 1)];
      let t112_j = col_i96 - (1);
      let t112 = t112_j >= 0 && t112_j < t107;
      let t113 = 0;
      let t60 = t112 ? t111 : t113;
      arr140.push(t60);
    }
    let arr145 = [];
    for (let col_i117 = 0; col_i117 < rows_el93.length; col_i117++) {
      let col_el116 = rows_el93[col_i117];
      let t118 = arr115.length;
      let t119 = arr115[Math.min(Math.max(col_i117 - (-1), 0), t118 - 1)];
      let t120_j = col_i117 - (-1);
      let t120 = t120_j >= 0 && t120_j < t118;
      let t121 = 0;
      let t65 = t120 ? t119 : t121;
      let t122 = arr115[Math.min(Math.max(col_i117 - (1), 0), t118 - 1)];
      let t123_j = col_i117 - (1);
      let t123 = t123_j >= 0 && t123_j < t118;
      let t124 = 0;
      let t70 = t123 ? t122 : t124;
      let t127 = arr126.length;
      let t128 = arr126[Math.min(Math.max(col_i117 - (-1), 0), t127 - 1)];
      let t129_j = col_i117 - (-1);
      let t129 = t129_j >= 0 && t129_j < t127;
      let t130 = 0;
      let t75 = t129 ? t128 : t130;
      let t131 = arr126[Math.min(Math.max(col_i117 - (1), 0), t127 - 1)];
      let t132_j = col_i117 - (1);
      let t132 = t132_j >= 0 && t132_j < t127;
      let t133 = 0;
      let t80 = t132 ? t131 : t133;
      let t134 = arr115[col_i117];
      let t135 = arr126[col_i117];
      let acc0 = t134 + t135;
      let t138 = arr137[col_i117];
      let acc1 = acc0 + t138;
      let t141 = arr140[col_i117];
      let acc2 = acc1 + t141;
      let acc3 = acc2 + t65;
      let acc4 = acc3 + t70;
      let acc5 = acc4 + t75;
      let acc6 = acc5 + t80;
      let t142 = 2;
      let t85 = acc6 == t142;
      let t143 = 0;
      let t91 = col_el116 > t143;
      let t44 = t85 && t91;
      arr145.push(t44);
    }
    arr144.push(arr145);
  }
  return arr144;
}

export function _next_alive(input) {
  let t137 = input["rows"];
  let arr190 = [];
  for (let rows_i139 = 0; rows_i139 < t137.length; rows_i139++) {
    let rows_el138 = t137[rows_i139];
    let arr160 = [];
    let arr171 = [];
    let arr182 = [];
    let arr185 = [];
    for (let col_i141 = 0; col_i141 < rows_el138.length; col_i141++) {
      let col_el140 = rows_el138[col_i141];
      let t142 = input["rows"];
      let t143 = t142.length;
      let t144 = t142[Math.min(Math.max(rows_i139 - (-1), 0), t143 - 1)];
      let t145 = t144[col_i141];
      let t146_j = rows_i139 - (-1);
      let t146 = t146_j >= 0 && t146_j < t143;
      let t147 = 0;
      let t51 = t146 ? t145 : t147;
      arr160.push(t51);
      let t148 = t142[Math.min(Math.max(rows_i139 - (1), 0), t143 - 1)];
      let t149 = t148[col_i141];
      let t150_j = rows_i139 - (1);
      let t150 = t150_j >= 0 && t150_j < t143;
      let t151 = 0;
      let t55 = t150 ? t149 : t151;
      arr171.push(t55);
      let t152 = rows_el138.length;
      let t153 = rows_el138[Math.min(Math.max(col_i141 - (-1), 0), t152 - 1)];
      let t154_j = col_i141 - (-1);
      let t154 = t154_j >= 0 && t154_j < t152;
      let t155 = 0;
      let t59 = t154 ? t153 : t155;
      arr182.push(t59);
      let t156 = rows_el138[Math.min(Math.max(col_i141 - (1), 0), t152 - 1)];
      let t157_j = col_i141 - (1);
      let t157 = t157_j >= 0 && t157_j < t152;
      let t158 = 0;
      let t63 = t157 ? t156 : t158;
      arr185.push(t63);
    }
    let arr191 = [];
    for (let col_i162 = 0; col_i162 < rows_el138.length; col_i162++) {
      let col_el161 = rows_el138[col_i162];
      let t163 = arr160.length;
      let t164 = arr160[Math.min(Math.max(col_i162 - (-1), 0), t163 - 1)];
      let t165_j = col_i162 - (-1);
      let t165 = t165_j >= 0 && t165_j < t163;
      let t166 = 0;
      let t68 = t165 ? t164 : t166;
      let t167 = arr160[Math.min(Math.max(col_i162 - (1), 0), t163 - 1)];
      let t168_j = col_i162 - (1);
      let t168 = t168_j >= 0 && t168_j < t163;
      let t169 = 0;
      let t73 = t168 ? t167 : t169;
      let t172 = arr171.length;
      let t173 = arr171[Math.min(Math.max(col_i162 - (-1), 0), t172 - 1)];
      let t174_j = col_i162 - (-1);
      let t174 = t174_j >= 0 && t174_j < t172;
      let t175 = 0;
      let t78 = t174 ? t173 : t175;
      let t176 = arr171[Math.min(Math.max(col_i162 - (1), 0), t172 - 1)];
      let t177_j = col_i162 - (1);
      let t177 = t177_j >= 0 && t177_j < t172;
      let t178 = 0;
      let t83 = t177 ? t176 : t178;
      let t179 = arr160[col_i162];
      let t180 = arr171[col_i162];
      let acc0 = t179 + t180;
      let t183 = arr182[col_i162];
      let acc1 = acc0 + t183;
      let t186 = arr185[col_i162];
      let acc2 = acc1 + t186;
      let acc3 = acc2 + t68;
      let acc4 = acc3 + t73;
      let acc5 = acc4 + t78;
      let acc6 = acc5 + t83;
      let t187 = 3;
      let t88 = acc6 == t187;
      let t188 = 2;
      let t129 = acc6 == t188;
      let t189 = 0;
      let t135 = col_el161 > t189;
      let t136 = t129 && t135;
      let t47 = t88 || t136;
      arr191.push(t47);
    }
    arr190.push(arr191);
  }
  return arr190;
}

export function _next_state(input) {
  let t144 = input["rows"];
  let arr198 = [];
  for (let rows_i146 = 0; rows_i146 < t144.length; rows_i146++) {
    let rows_el145 = t144[rows_i146];
    let arr167 = [];
    let arr178 = [];
    let arr189 = [];
    let arr192 = [];
    for (let col_i148 = 0; col_i148 < rows_el145.length; col_i148++) {
      let col_el147 = rows_el145[col_i148];
      let t149 = input["rows"];
      let t150 = t149.length;
      let t151 = t149[Math.min(Math.max(rows_i146 - (-1), 0), t150 - 1)];
      let t152 = t151[col_i148];
      let t153_j = rows_i146 - (-1);
      let t153 = t153_j >= 0 && t153_j < t150;
      let t154 = 0;
      let t57 = t153 ? t152 : t154;
      arr167.push(t57);
      let t155 = t149[Math.min(Math.max(rows_i146 - (1), 0), t150 - 1)];
      let t156 = t155[col_i148];
      let t157_j = rows_i146 - (1);
      let t157 = t157_j >= 0 && t157_j < t150;
      let t158 = 0;
      let t61 = t157 ? t156 : t158;
      arr178.push(t61);
      let t159 = rows_el145.length;
      let t160 = rows_el145[Math.min(Math.max(col_i148 - (-1), 0), t159 - 1)];
      let t161_j = col_i148 - (-1);
      let t161 = t161_j >= 0 && t161_j < t159;
      let t162 = 0;
      let t65 = t161 ? t160 : t162;
      arr189.push(t65);
      let t163 = rows_el145[Math.min(Math.max(col_i148 - (1), 0), t159 - 1)];
      let t164_j = col_i148 - (1);
      let t164 = t164_j >= 0 && t164_j < t159;
      let t165 = 0;
      let t69 = t164 ? t163 : t165;
      arr192.push(t69);
    }
    let arr199 = [];
    for (let col_i169 = 0; col_i169 < rows_el145.length; col_i169++) {
      let col_el168 = rows_el145[col_i169];
      let t170 = arr167.length;
      let t171 = arr167[Math.min(Math.max(col_i169 - (-1), 0), t170 - 1)];
      let t172_j = col_i169 - (-1);
      let t172 = t172_j >= 0 && t172_j < t170;
      let t173 = 0;
      let t74 = t172 ? t171 : t173;
      let t174 = arr167[Math.min(Math.max(col_i169 - (1), 0), t170 - 1)];
      let t175_j = col_i169 - (1);
      let t175 = t175_j >= 0 && t175_j < t170;
      let t176 = 0;
      let t79 = t175 ? t174 : t176;
      let t179 = arr178.length;
      let t180 = arr178[Math.min(Math.max(col_i169 - (-1), 0), t179 - 1)];
      let t181_j = col_i169 - (-1);
      let t181 = t181_j >= 0 && t181_j < t179;
      let t182 = 0;
      let t84 = t181 ? t180 : t182;
      let t183 = arr178[Math.min(Math.max(col_i169 - (1), 0), t179 - 1)];
      let t184_j = col_i169 - (1);
      let t184 = t184_j >= 0 && t184_j < t179;
      let t185 = 0;
      let t89 = t184 ? t183 : t185;
      let t186 = arr167[col_i169];
      let t187 = arr178[col_i169];
      let acc0 = t186 + t187;
      let t190 = arr189[col_i169];
      let acc1 = acc0 + t190;
      let t193 = arr192[col_i169];
      let acc2 = acc1 + t193;
      let acc3 = acc2 + t74;
      let acc4 = acc3 + t79;
      let acc5 = acc4 + t84;
      let acc6 = acc5 + t89;
      let t194 = 3;
      let t94 = acc6 == t194;
      let t195 = 2;
      let t135 = acc6 == t195;
      let t196 = 0;
      let t141 = col_el168 > t196;
      let t142 = t135 && t141;
      let t143 = t94 || t142;
      let t197 = 1;
      let t53 = t143 ? t197 : t196;
      arr199.push(t53);
    }
    arr198.push(arr199);
  }
  return arr198;
}

