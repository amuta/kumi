export function _pre(input) {
  let t17 = input["hidden"];
  let arr27 = [];
  for (let hidden_i19 = 0; hidden_i19 < t17.length; hidden_i19++) {
    let hidden_el18 = t17[hidden_i19];
    let t20 = hidden_el18["win"];
    let acc25 = 0.0;
    for (let win_i22 = 0; win_i22 < t20.length; win_i22++) {
      let win_el21 = t20[win_i22];
      let t23 = win_el21["w"];
      let t24 = win_el21["x"];
      let t11 = t23 * t24;
      acc25 += t11;
    }
    let t12 = acc25;
    let t26 = hidden_el18["b1"];
    let t16 = t12 + t26;
    arr27.push(t16);
  }
  return arr27;
}

export function _h(input) {
  let t35 = input["hidden"];
  let arr45 = [];
  for (let hidden_i37 = 0; hidden_i37 < t35.length; hidden_i37++) {
    let hidden_el36 = t35[hidden_i37];
    let t38 = hidden_el36["win"];
    let acc43 = 0.0;
    for (let win_i40 = 0; win_i40 < t38.length; win_i40++) {
      let win_el39 = t38[win_i40];
      let t41 = win_el39["w"];
      let t42 = win_el39["x"];
      let t29 = t41 * t42;
      acc43 += t29;
    }
    let t30 = acc43;
    let t44 = hidden_el36["b1"];
    let t34 = t30 + t44;
    let t18 = Math.tanh(t34);
    arr45.push(t18);
  }
  return arr45;
}

export function _o_pre(input) {
  let t44 = input["hidden"];
  let acc55 = 0.0;
  for (let hidden_i46 = 0; hidden_i46 < t44.length; hidden_i46++) {
    let hidden_el45 = t44[hidden_i46];
    let t47 = hidden_el45["win"];
    let acc52 = 0.0;
    for (let win_i49 = 0; win_i49 < t47.length; win_i49++) {
      let win_el48 = t47[win_i49];
      let t50 = win_el48["w"];
      let t51 = win_el48["x"];
      let t37 = t50 * t51;
      acc52 += t37;
    }
    let t38 = acc52;
    let t53 = hidden_el45["b1"];
    let t42 = t38 + t53;
    let t43 = Math.tanh(t42);
    let t54 = hidden_el45["w2"];
    let t23 = t54 * t43;
    acc55 += t23;
  }
  let t24 = acc55;
  let t56 = input["b_out"];
  let t26 = t24 + t56;
  return t26;
}

export function _o(input) {
  let t59 = input["hidden"];
  let acc70 = 0.0;
  for (let hidden_i61 = 0; hidden_i61 < t59.length; hidden_i61++) {
    let hidden_el60 = t59[hidden_i61];
    let t62 = hidden_el60["win"];
    let acc67 = 0.0;
    for (let win_i64 = 0; win_i64 < t62.length; win_i64++) {
      let win_el63 = t62[win_i64];
      let t65 = win_el63["w"];
      let t66 = win_el63["x"];
      let t48 = t65 * t66;
      acc67 += t48;
    }
    let t49 = acc67;
    let t68 = hidden_el60["b1"];
    let t53 = t49 + t68;
    let t54 = Math.tanh(t53);
    let t69 = hidden_el60["w2"];
    let t55 = t69 * t54;
    acc70 += t55;
  }
  let t56 = acc70;
  let t71 = input["b_out"];
  let t58 = t56 + t71;
  let t72 = 0.0;
  let t31 = t72 - t58;
  let t32 = Math.exp(t31);
  let t73 = 1.0;
  let t33 = t73 + t32;
  let t34 = t73 / t33;
  return t34;
}

export function _output(input) {
  let t67 = input["hidden"];
  let acc78 = 0.0;
  for (let hidden_i69 = 0; hidden_i69 < t67.length; hidden_i69++) {
    let hidden_el68 = t67[hidden_i69];
    let t70 = hidden_el68["win"];
    let acc75 = 0.0;
    for (let win_i72 = 0; win_i72 < t70.length; win_i72++) {
      let win_el71 = t70[win_i72];
      let t73 = win_el71["w"];
      let t74 = win_el71["x"];
      let t52 = t73 * t74;
      acc75 += t52;
    }
    let t53 = acc75;
    let t76 = hidden_el68["b1"];
    let t57 = t53 + t76;
    let t58 = Math.tanh(t57);
    let t77 = hidden_el68["w2"];
    let t59 = t77 * t58;
    acc78 += t59;
  }
  let t60 = acc78;
  let t79 = input["b_out"];
  let t62 = t60 + t79;
  let t80 = 0.0;
  let t63 = t80 - t62;
  let t64 = Math.exp(t63);
  let t81 = 1.0;
  let t65 = t81 + t64;
  let t66 = t81 / t65;
  return t66;
}

export function _oc(input) {
  let t71 = input["hidden"];
  let acc82 = 0.0;
  for (let hidden_i73 = 0; hidden_i73 < t71.length; hidden_i73++) {
    let hidden_el72 = t71[hidden_i73];
    let t74 = hidden_el72["win"];
    let acc79 = 0.0;
    for (let win_i76 = 0; win_i76 < t74.length; win_i76++) {
      let win_el75 = t74[win_i76];
      let t77 = win_el75["w"];
      let t78 = win_el75["x"];
      let t56 = t77 * t78;
      acc79 += t56;
    }
    let t57 = acc79;
    let t80 = hidden_el72["b1"];
    let t61 = t57 + t80;
    let t62 = Math.tanh(t61);
    let t81 = hidden_el72["w2"];
    let t63 = t81 * t62;
    acc82 += t63;
  }
  let t64 = acc82;
  let t83 = input["b_out"];
  let t66 = t64 + t83;
  let t84 = 0.0;
  let t67 = t84 - t66;
  let t68 = Math.exp(t67);
  let t85 = 1.0;
  let t69 = t85 + t68;
  let t70 = t85 / t69;
  let t86 = 1.0e-06;
  let t87 = 0.999999;
  let t39 = Math.min(Math.max(t70, t86), t87);
  return t39;
}

export function _loss(input) {
  let t89 = input["hidden"];
  let acc100 = 0.0;
  for (let hidden_i91 = 0; hidden_i91 < t89.length; hidden_i91++) {
    let hidden_el90 = t89[hidden_i91];
    let t92 = hidden_el90["win"];
    let acc97 = 0.0;
    for (let win_i94 = 0; win_i94 < t92.length; win_i94++) {
      let win_el93 = t92[win_i94];
      let t95 = win_el93["w"];
      let t96 = win_el93["x"];
      let t71 = t95 * t96;
      acc97 += t71;
    }
    let t72 = acc97;
    let t98 = hidden_el90["b1"];
    let t76 = t72 + t98;
    let t77 = Math.tanh(t76);
    let t99 = hidden_el90["w2"];
    let t78 = t99 * t77;
    acc100 += t78;
  }
  let t79 = acc100;
  let t101 = input["b_out"];
  let t81 = t79 + t101;
  let t102 = 0.0;
  let t82 = t102 - t81;
  let t83 = Math.exp(t82);
  let t103 = 1.0;
  let t84 = t103 + t83;
  let t85 = t103 / t84;
  let t104 = 1.0e-06;
  let t105 = 0.999999;
  let t88 = Math.min(Math.max(t85, t104), t105);
  let t43 = Math.log(t88);
  let t106 = input["y"];
  let t44 = t106 * t43;
  let t47 = t103 - t106;
  let t50 = t103 - t88;
  let t51 = Math.log(t50);
  let t52 = t47 * t51;
  let t53 = t44 + t52;
  let t54 = t102 - t53;
  return t54;
}

export function _dpre_out(input) {
  let t89 = input["hidden"];
  let acc100 = 0.0;
  for (let hidden_i91 = 0; hidden_i91 < t89.length; hidden_i91++) {
    let hidden_el90 = t89[hidden_i91];
    let t92 = hidden_el90["win"];
    let acc97 = 0.0;
    for (let win_i94 = 0; win_i94 < t92.length; win_i94++) {
      let win_el93 = t92[win_i94];
      let t95 = win_el93["w"];
      let t96 = win_el93["x"];
      let t74 = t95 * t96;
      acc97 += t74;
    }
    let t75 = acc97;
    let t98 = hidden_el90["b1"];
    let t79 = t75 + t98;
    let t80 = Math.tanh(t79);
    let t99 = hidden_el90["w2"];
    let t81 = t99 * t80;
    acc100 += t81;
  }
  let t82 = acc100;
  let t101 = input["b_out"];
  let t84 = t82 + t101;
  let t102 = 0.0;
  let t85 = t102 - t84;
  let t86 = Math.exp(t85);
  let t103 = 1.0;
  let t87 = t103 + t86;
  let t88 = t103 / t87;
  let t104 = input["y"];
  let t57 = t88 - t104;
  return t57;
}

export function _dh(input) {
  let t97 = input["hidden"];
  let acc108 = 0.0;
  for (let hidden_i99 = 0; hidden_i99 < t97.length; hidden_i99++) {
    let hidden_el98 = t97[hidden_i99];
    let t100 = hidden_el98["win"];
    let acc105 = 0.0;
    for (let win_i102 = 0; win_i102 < t100.length; win_i102++) {
      let win_el101 = t100[win_i102];
      let t103 = win_el101["w"];
      let t104 = win_el101["x"];
      let t80 = t103 * t104;
      acc105 += t80;
    }
    let t81 = acc105;
    let t106 = hidden_el98["b1"];
    let t85 = t81 + t106;
    let t86 = Math.tanh(t85);
    let t107 = hidden_el98["w2"];
    let t87 = t107 * t86;
    acc108 += t87;
  }
  let t88 = acc108;
  let t109 = input["b_out"];
  let t90 = t88 + t109;
  let t110 = 0.0;
  let t91 = t110 - t90;
  let t92 = Math.exp(t91);
  let t111 = 1.0;
  let t93 = t111 + t92;
  let t94 = t111 / t93;
  let t112 = input["y"];
  let t96 = t94 - t112;
  let arr116 = [];
  for (let hidden_i114 = 0; hidden_i114 < t97.length; hidden_i114++) {
    let hidden_el113 = t97[hidden_i114];
    let t115 = hidden_el113["w2"];
    let t63 = t96 * t115;
    arr116.push(t63);
  }
  return arr116;
}

export function _dpre(input) {
  let t110 = input["hidden"];
  let acc121 = 0.0;
  let arr129 = [];
  for (let hidden_i112 = 0; hidden_i112 < t110.length; hidden_i112++) {
    let hidden_el111 = t110[hidden_i112];
    let t113 = hidden_el111["win"];
    let acc118 = 0.0;
    for (let win_i115 = 0; win_i115 < t113.length; win_i115++) {
      let win_el114 = t113[win_i115];
      let t116 = win_el114["w"];
      let t117 = win_el114["x"];
      let t88 = t116 * t117;
      acc118 += t88;
    }
    let t89 = acc118;
    let t119 = hidden_el111["b1"];
    let t93 = t89 + t119;
    let t94 = Math.tanh(t93);
    arr129.push(t94);
    let t120 = hidden_el111["w2"];
    let t95 = t120 * t94;
    acc121 += t95;
  }
  let t96 = acc121;
  let t122 = input["b_out"];
  let t98 = t96 + t122;
  let t123 = 0.0;
  let t99 = t123 - t98;
  let t100 = Math.exp(t99);
  let t124 = 1.0;
  let t101 = t124 + t100;
  let t102 = t124 / t101;
  let t125 = input["y"];
  let t104 = t102 - t125;
  let arr132 = [];
  for (let hidden_i127 = 0; hidden_i127 < t110.length; hidden_i127++) {
    let hidden_el126 = t110[hidden_i127];
    let t128 = hidden_el126["w2"];
    let t109 = t104 * t128;
    let t130 = arr129[hidden_i127];
    let t69 = t130 * t130;
    let t131 = 1.0;
    let t70 = t131 - t69;
    let t71 = t109 * t70;
    arr132.push(t71);
  }
  return arr132;
}

export function _grad_b_out(input) {
  let t106 = input["hidden"];
  let acc117 = 0.0;
  for (let hidden_i108 = 0; hidden_i108 < t106.length; hidden_i108++) {
    let hidden_el107 = t106[hidden_i108];
    let t109 = hidden_el107["win"];
    let acc114 = 0.0;
    for (let win_i111 = 0; win_i111 < t109.length; win_i111++) {
      let win_el110 = t109[win_i111];
      let t112 = win_el110["w"];
      let t113 = win_el110["x"];
      let t89 = t112 * t113;
      acc114 += t89;
    }
    let t90 = acc114;
    let t115 = hidden_el107["b1"];
    let t94 = t90 + t115;
    let t95 = Math.tanh(t94);
    let t116 = hidden_el107["w2"];
    let t96 = t116 * t95;
    acc117 += t96;
  }
  let t97 = acc117;
  let t118 = input["b_out"];
  let t99 = t97 + t118;
  let t119 = 0.0;
  let t100 = t119 - t99;
  let t101 = Math.exp(t100);
  let t120 = 1.0;
  let t102 = t120 + t101;
  let t103 = t120 / t102;
  let t121 = input["y"];
  let t105 = t103 - t121;
  return t105;
}

export function _grad_w2(input) {
  let t110 = input["hidden"];
  let acc121 = 0.0;
  let arr128 = [];
  for (let hidden_i112 = 0; hidden_i112 < t110.length; hidden_i112++) {
    let hidden_el111 = t110[hidden_i112];
    let t113 = hidden_el111["win"];
    let acc118 = 0.0;
    for (let win_i115 = 0; win_i115 < t113.length; win_i115++) {
      let win_el114 = t113[win_i115];
      let t116 = win_el114["w"];
      let t117 = win_el114["x"];
      let t93 = t116 * t117;
      acc118 += t93;
    }
    let t94 = acc118;
    let t119 = hidden_el111["b1"];
    let t98 = t94 + t119;
    let t99 = Math.tanh(t98);
    arr128.push(t99);
    let t120 = hidden_el111["w2"];
    let t100 = t120 * t99;
    acc121 += t100;
  }
  let t101 = acc121;
  let t122 = input["b_out"];
  let t103 = t101 + t122;
  let t123 = 0.0;
  let t104 = t123 - t103;
  let t105 = Math.exp(t104);
  let t124 = 1.0;
  let t106 = t124 + t105;
  let t107 = t124 / t106;
  let t125 = input["y"];
  let t109 = t107 - t125;
  let arr130 = [];
  for (let hidden_i127 = 0; hidden_i127 < t110.length; hidden_i127++) {
    let hidden_el126 = t110[hidden_i127];
    let t129 = arr128[hidden_i127];
    let t76 = t109 * t129;
    arr130.push(t76);
  }
  return arr130;
}

export function _grad_b1(input) {
  let t155 = input["hidden"];
  let acc166 = 0.0;
  let arr174 = [];
  for (let hidden_i157 = 0; hidden_i157 < t155.length; hidden_i157++) {
    let hidden_el156 = t155[hidden_i157];
    let t158 = hidden_el156["win"];
    let acc163 = 0.0;
    for (let win_i160 = 0; win_i160 < t158.length; win_i160++) {
      let win_el159 = t158[win_i160];
      let t161 = win_el159["w"];
      let t162 = win_el159["x"];
      let t94 = t161 * t162;
      acc163 += t94;
    }
    let t95 = acc163;
    let t164 = hidden_el156["b1"];
    let t99 = t95 + t164;
    let t100 = Math.tanh(t99);
    arr174.push(t100);
    let t165 = hidden_el156["w2"];
    let t101 = t165 * t100;
    acc166 += t101;
  }
  let t102 = acc166;
  let t167 = input["b_out"];
  let t104 = t102 + t167;
  let t168 = 0.0;
  let t105 = t168 - t104;
  let t106 = Math.exp(t105);
  let t169 = 1.0;
  let t107 = t169 + t106;
  let t108 = t169 / t107;
  let t170 = input["y"];
  let t110 = t108 - t170;
  let arr177 = [];
  for (let hidden_i172 = 0; hidden_i172 < t155.length; hidden_i172++) {
    let hidden_el171 = t155[hidden_i172];
    let t173 = hidden_el171["w2"];
    let t115 = t110 * t173;
    let t175 = arr174[hidden_i172];
    let t152 = t175 * t175;
    let t176 = 1.0;
    let t153 = t176 - t152;
    let t154 = t115 * t153;
    arr177.push(t154);
  }
  return arr177;
}

export function _grad_w1(input) {
  let t163 = input["hidden"];
  let acc174 = 0.0;
  let arr182 = [];
  for (let hidden_i165 = 0; hidden_i165 < t163.length; hidden_i165++) {
    let hidden_el164 = t163[hidden_i165];
    let t166 = hidden_el164["win"];
    let acc171 = 0.0;
    for (let win_i168 = 0; win_i168 < t166.length; win_i168++) {
      let win_el167 = t166[win_i168];
      let t169 = win_el167["w"];
      let t170 = win_el167["x"];
      let t102 = t169 * t170;
      acc171 += t102;
    }
    let t103 = acc171;
    let t172 = hidden_el164["b1"];
    let t107 = t103 + t172;
    let t108 = Math.tanh(t107);
    arr182.push(t108);
    let t173 = hidden_el164["w2"];
    let t109 = t173 * t108;
    acc174 += t109;
  }
  let t110 = acc174;
  let t175 = input["b_out"];
  let t112 = t110 + t175;
  let t176 = 0.0;
  let t113 = t176 - t112;
  let t114 = Math.exp(t113);
  let t177 = 1.0;
  let t115 = t177 + t114;
  let t116 = t177 / t115;
  let t178 = input["y"];
  let t118 = t116 - t178;
  let arr189 = [];
  for (let hidden_i180 = 0; hidden_i180 < t163.length; hidden_i180++) {
    let hidden_el179 = t163[hidden_i180];
    let t181 = hidden_el179["w2"];
    let t123 = t118 * t181;
    let t183 = arr182[hidden_i180];
    let t160 = t183 * t183;
    let t184 = 1.0;
    let t161 = t184 - t160;
    let t162 = t123 * t161;
    let t185 = hidden_el179["win"];
    let arr190 = [];
    for (let win_i187 = 0; win_i187 < t185.length; win_i187++) {
      let win_el186 = t185[win_i187];
      let t188 = win_el186["x"];
      let t85 = t162 * t188;
      arr190.push(t85);
    }
    arr189.push(arr190);
  }
  return arr189;
}

