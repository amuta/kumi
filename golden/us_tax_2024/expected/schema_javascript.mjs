export function _state_tax(input) {
  let t4 = input["income"];
  let t5 = input["state_rate"];
  let t3 = t4 * t5;
  return t3;
}

export function _local_tax(input) {
  let t7 = input["income"];
  let t8 = input["local_rate"];
  let t6 = t7 * t8;
  return t6;
}

export function _taxable(input) {
  let t14 = input["statuses"];
  let arr20 = [];
  for (let statuses_i16 = 0; statuses_i16 < t14.length; statuses_i16++) {
    let statuses_el15 = t14[statuses_i16];
    let t17 = input["income"];
    let t18 = statuses_el15["std"];
    let t12 = t17 - t18;
    let t19 = 0;
    let acc0 = Math.max(t12, t19);
    arr20.push(acc0);
  }
  return arr20;
}

export function _lo(input) {
  let t21 = input["statuses"];
  let arr29 = [];
  for (let statuses_i23 = 0; statuses_i23 < t21.length; statuses_i23++) {
    let statuses_el22 = t21[statuses_i23];
    let t24 = statuses_el22["rates"];
    let arr30 = [];
    for (let rates_i26 = 0; rates_i26 < t24.length; rates_i26++) {
      let rates_el25 = t24[rates_i26];
      let t27 = rates_el25["lo"];
      let t28 = t27;
      arr30.push(t28);
    }
    arr29.push(arr30);
  }
  return arr29;
}

export function _hi(input) {
  let t26 = input["statuses"];
  let arr34 = [];
  for (let statuses_i28 = 0; statuses_i28 < t26.length; statuses_i28++) {
    let statuses_el27 = t26[statuses_i28];
    let t29 = statuses_el27["rates"];
    let arr35 = [];
    for (let rates_i31 = 0; rates_i31 < t29.length; rates_i31++) {
      let rates_el30 = t29[rates_i31];
      let t32 = rates_el30["hi"];
      let t33 = t32;
      arr35.push(t33);
    }
    arr34.push(arr35);
  }
  return arr34;
}

export function _rate(input) {
  let t31 = input["statuses"];
  let arr39 = [];
  for (let statuses_i33 = 0; statuses_i33 < t31.length; statuses_i33++) {
    let statuses_el32 = t31[statuses_i33];
    let t34 = statuses_el32["rates"];
    let arr40 = [];
    for (let rates_i36 = 0; rates_i36 < t34.length; rates_i36++) {
      let rates_el35 = t34[rates_i36];
      let t37 = rates_el35["rate"];
      let t38 = t37;
      arr40.push(t38);
    }
    arr39.push(arr40);
  }
  return arr39;
}

export function _big_hi(input) {
  let t32 = 100000000000.0;
  return t32;
}

export function _hi_eff(input) {
  let t45 = input["statuses"];
  let arr54 = [];
  for (let statuses_i47 = 0; statuses_i47 < t45.length; statuses_i47++) {
    let statuses_el46 = t45[statuses_i47];
    let t48 = statuses_el46["rates"];
    let arr55 = [];
    for (let rates_i50 = 0; rates_i50 < t48.length; rates_i50++) {
      let rates_el49 = t48[rates_i50];
      let t51 = rates_el49["hi"];
      let t52 = -1;
      let t35 = t51 == t52;
      let t53 = 100000000000.0;
      let t39 = t35 ? t53 : t51;
      arr55.push(t39);
    }
    arr54.push(arr55);
  }
  return arr54;
}

export function _amt(input) {
  let t80 = input["statuses"];
  let arr94 = [];
  for (let statuses_i82 = 0; statuses_i82 < t80.length; statuses_i82++) {
    let statuses_el81 = t80[statuses_i82];
    let t83 = input["income"];
    let t84 = statuses_el81["std"];
    let t55 = t83 - t84;
    let t85 = 0;
    let acc0 = Math.max(t55, t85);
    let t86 = statuses_el81["rates"];
    let arr95 = [];
    for (let rates_i88 = 0; rates_i88 < t86.length; rates_i88++) {
      let rates_el87 = t86[rates_i88];
      let t89 = rates_el87["lo"];
      let t43 = acc0 - t89;
      let t90 = rates_el87["hi"];
      let t91 = -1;
      let t71 = t90 == t91;
      let t92 = 100000000000.0;
      let t79 = t71 ? t92 : t90;
      let t48 = t79 - t89;
      let t93 = 0;
      let t49 = Math.min(Math.max(t43, t93), t48);
      arr95.push(t49);
    }
    arr94.push(arr95);
  }
  return arr94;
}

export function _fed_tax(input) {
  let t100 = input["statuses"];
  let arr116 = [];
  for (let statuses_i102 = 0; statuses_i102 < t100.length; statuses_i102++) {
    let statuses_el101 = t100[statuses_i102];
    let t103 = input["income"];
    let t104 = statuses_el101["std"];
    let t59 = t103 - t104;
    let t105 = 0;
    let acc0 = Math.max(t59, t105);
    let t106 = statuses_el101["rates"];
    let acc115 = 0.0;
    for (let rates_i108 = 0; rates_i108 < t106.length; rates_i108++) {
      let rates_el107 = t106[rates_i108];
      let t109 = rates_el107["lo"];
      let t69 = acc0 - t109;
      let t110 = rates_el107["hi"];
      let t111 = -1;
      let t79 = t110 == t111;
      let t112 = 100000000000.0;
      let t87 = t79 ? t112 : t110;
      let t93 = t87 - t109;
      let t113 = 0;
      let t94 = Math.min(Math.max(t69, t113), t93);
      let t114 = rates_el107["rate"];
      let t52 = t94 * t114;
      acc115 += t52;
    }
    let t53 = acc115;
    arr116.push(t53);
  }
  return arr116;
}

export function _in_br(input) {
  let t102 = input["statuses"];
  let arr115 = [];
  for (let statuses_i104 = 0; statuses_i104 < t102.length; statuses_i104++) {
    let statuses_el103 = t102[statuses_i104];
    let t105 = input["income"];
    let t106 = statuses_el103["std"];
    let t68 = t105 - t106;
    let t107 = 0;
    let acc0 = Math.max(t68, t107);
    let t108 = statuses_el103["rates"];
    let arr116 = [];
    for (let rates_i110 = 0; rates_i110 < t108.length; rates_i110++) {
      let rates_el109 = t108[rates_i110];
      let t111 = rates_el109["lo"];
      let t57 = acc0 >= t111;
      let t112 = rates_el109["hi"];
      let t113 = -1;
      let t93 = t112 == t113;
      let t114 = 100000000000.0;
      let t101 = t93 ? t114 : t112;
      let t61 = acc0 < t101;
      let t62 = t57 && t61;
      arr116.push(t62);
    }
    arr115.push(arr116);
  }
  return arr115;
}

export function _fed_marg(input) {
  let t118 = input["statuses"];
  let arr134 = [];
  for (let statuses_i120 = 0; statuses_i120 < t118.length; statuses_i120++) {
    let statuses_el119 = t118[statuses_i120];
    let t121 = input["income"];
    let t122 = statuses_el119["std"];
    let t74 = t121 - t122;
    let t123 = 0;
    let acc0 = Math.max(t74, t123);
    let t124 = statuses_el119["rates"];
    let acc133 = 0.0;
    for (let rates_i126 = 0; rates_i126 < t124.length; rates_i126++) {
      let rates_el125 = t124[rates_i126];
      let t127 = rates_el125["lo"];
      let t84 = acc0 >= t127;
      let t128 = rates_el125["hi"];
      let t129 = -1;
      let t102 = t128 == t129;
      let t130 = 100000000000.0;
      let t110 = t102 ? t130 : t128;
      let t111 = acc0 < t110;
      let t112 = t84 && t111;
      let t131 = rates_el125["rate"];
      let t132 = 0;
      let t67 = t112 ? t131 : t132;
      acc133 += t67;
    }
    let t68 = acc133;
    arr134.push(t68);
  }
  return arr134;
}

export function _fed_eff(input) {
  let t124 = input["statuses"];
  let t140 = input["income"];
  let t141 = 1.0;
  let acc1 = Math.max(t140, t141);
  let arr146 = [];
  for (let statuses_i126 = 0; statuses_i126 < t124.length; statuses_i126++) {
    let statuses_el125 = t124[statuses_i126];
    let t127 = input["income"];
    let t128 = statuses_el125["std"];
    let t81 = t127 - t128;
    let t129 = 0;
    let acc0 = Math.max(t81, t129);
    let t130 = statuses_el125["rates"];
    let acc139 = 0.0;
    for (let rates_i132 = 0; rates_i132 < t130.length; rates_i132++) {
      let rates_el131 = t130[rates_i132];
      let t133 = rates_el131["lo"];
      let t91 = acc0 - t133;
      let t134 = rates_el131["hi"];
      let t135 = -1;
      let t101 = t134 == t135;
      let t136 = 100000000000.0;
      let t109 = t101 ? t136 : t134;
      let t115 = t109 - t133;
      let t137 = 0;
      let t116 = Math.min(Math.max(t91, t137), t115);
      let t138 = rates_el131["rate"];
      let t122 = t116 * t138;
      acc139 += t122;
    }
    let t123 = acc139;
    let t75 = t123 / acc1;
    arr146.push(t75);
  }
  return arr146;
}

export function _ss_wage_base(input) {
  let t77 = 168600.0;
  return t77;
}

export function _ss_rate(input) {
  let t78 = 0.062;
  return t78;
}

export function _ss_tax(input) {
  let t84 = input["income"];
  let t85 = 168600.0;
  let acc0 = Math.min(t84, t85);
  let t86 = 0.062;
  let t83 = acc0 * t86;
  return t83;
}

export function _med_base_rate(input) {
  let t85 = 0.0145;
  return t85;
}

export function _med_tax(input) {
  let t88 = input["income"];
  let t89 = 0.0145;
  let t87 = t88 * t89;
  return t87;
}

export function _addl_med_rate(input) {
  let t89 = 0.009;
  return t89;
}

export function _addl_med_tax(input) {
  let t101 = input["statuses"];
  let arr108 = [];
  for (let statuses_i103 = 0; statuses_i103 < t101.length; statuses_i103++) {
    let statuses_el102 = t101[statuses_i103];
    let t104 = input["income"];
    let t105 = statuses_el102["addl_threshold"];
    let t94 = t104 - t105;
    let t106 = 0;
    let acc0 = Math.max(t94, t106);
    let t107 = 0.009;
    let t100 = acc0 * t107;
    arr108.push(t100);
  }
  return arr108;
}

export function _fica_tax(input) {
  let t128 = input["income"];
  let t129 = 168600.0;
  let acc0 = Math.min(t128, t129);
  let t130 = 0.062;
  let t112 = acc0 * t130;
  let t131 = 0.0145;
  let t115 = t128 * t131;
  let t103 = t112 + t115;
  let t132 = input["statuses"];
  let arr139 = [];
  for (let statuses_i134 = 0; statuses_i134 < t132.length; statuses_i134++) {
    let statuses_el133 = t132[statuses_i134];
    let t135 = input["income"];
    let t136 = statuses_el133["addl_threshold"];
    let t121 = t135 - t136;
    let t137 = 0;
    let acc1 = Math.max(t121, t137);
    let t138 = 0.009;
    let t127 = acc1 * t138;
    let t106 = t103 + t127;
    arr139.push(t106);
  }
  return arr139;
}

export function _fica_eff(input) {
  let t138 = input["income"];
  let t139 = 168600.0;
  let acc0 = Math.min(t138, t139);
  let t140 = 0.062;
  let t119 = acc0 * t140;
  let t141 = 0.0145;
  let t122 = t138 * t141;
  let t123 = t119 + t122;
  let t142 = input["statuses"];
  let t149 = 1.0;
  let acc2 = Math.max(t138, t149);
  let arr154 = [];
  for (let statuses_i144 = 0; statuses_i144 < t142.length; statuses_i144++) {
    let statuses_el143 = t142[statuses_i144];
    let t145 = input["income"];
    let t146 = statuses_el143["addl_threshold"];
    let t130 = t145 - t146;
    let t147 = 0;
    let acc1 = Math.max(t130, t147);
    let t148 = 0.009;
    let t136 = acc1 * t148;
    let t137 = t123 + t136;
    let t113 = t137 / acc2;
    arr154.push(t113);
  }
  return arr154;
}

export function _total_tax(input) {
  let t201 = input["statuses"];
  let t217 = input["income"];
  let t218 = 168600.0;
  let acc1 = Math.min(t217, t218);
  let t219 = 0.062;
  let t176 = acc1 * t219;
  let t220 = 0.0145;
  let t179 = t217 * t220;
  let t180 = t176 + t179;
  let t229 = input["state_rate"];
  let t197 = t217 * t229;
  let t234 = input["local_rate"];
  let t200 = t217 * t234;
  let arr239 = [];
  for (let statuses_i203 = 0; statuses_i203 < t201.length; statuses_i203++) {
    let statuses_el202 = t201[statuses_i203];
    let t204 = input["income"];
    let t205 = statuses_el202["std"];
    let t128 = t204 - t205;
    let t206 = 0;
    let acc0 = Math.max(t128, t206);
    let t207 = statuses_el202["rates"];
    let acc216 = 0.0;
    for (let rates_i209 = 0; rates_i209 < t207.length; rates_i209++) {
      let rates_el208 = t207[rates_i209];
      let t210 = rates_el208["lo"];
      let t138 = acc0 - t210;
      let t211 = rates_el208["hi"];
      let t212 = -1;
      let t148 = t211 == t212;
      let t213 = 100000000000.0;
      let t156 = t148 ? t213 : t211;
      let t162 = t156 - t210;
      let t214 = 0;
      let t163 = Math.min(Math.max(t138, t214), t162);
      let t215 = rates_el208["rate"];
      let t169 = t163 * t215;
      acc216 += t169;
    }
    let t170 = acc216;
    let t223 = input["income"];
    let t224 = statuses_el202["addl_threshold"];
    let t187 = t223 - t224;
    let t225 = 0;
    let acc2 = Math.max(t187, t225);
    let t226 = 0.009;
    let t193 = acc2 * t226;
    let t194 = t180 + t193;
    let t116 = t170 + t194;
    let t119 = t116 + t197;
    let t122 = t119 + t200;
    arr239.push(t122);
  }
  return arr239;
}

export function _total_eff(input) {
  let t213 = input["statuses"];
  let t229 = input["income"];
  let t230 = 168600.0;
  let acc1 = Math.min(t229, t230);
  let t231 = 0.062;
  let t183 = acc1 * t231;
  let t232 = 0.0145;
  let t186 = t229 * t232;
  let t187 = t183 + t186;
  let t241 = input["state_rate"];
  let t205 = t229 * t241;
  let t246 = input["local_rate"];
  let t210 = t229 * t246;
  let t251 = 1.0;
  let acc3 = Math.max(t229, t251);
  let arr256 = [];
  for (let statuses_i215 = 0; statuses_i215 < t213.length; statuses_i215++) {
    let statuses_el214 = t213[statuses_i215];
    let t216 = input["income"];
    let t217 = statuses_el214["std"];
    let t135 = t216 - t217;
    let t218 = 0;
    let acc0 = Math.max(t135, t218);
    let t219 = statuses_el214["rates"];
    let acc228 = 0.0;
    for (let rates_i221 = 0; rates_i221 < t219.length; rates_i221++) {
      let rates_el220 = t219[rates_i221];
      let t222 = rates_el220["lo"];
      let t145 = acc0 - t222;
      let t223 = rates_el220["hi"];
      let t224 = -1;
      let t155 = t223 == t224;
      let t225 = 100000000000.0;
      let t163 = t155 ? t225 : t223;
      let t169 = t163 - t222;
      let t226 = 0;
      let t170 = Math.min(Math.max(t145, t226), t169);
      let t227 = rates_el220["rate"];
      let t176 = t170 * t227;
      acc228 += t176;
    }
    let t177 = acc228;
    let t235 = input["income"];
    let t236 = statuses_el214["addl_threshold"];
    let t194 = t235 - t236;
    let t237 = 0;
    let acc2 = Math.max(t194, t237);
    let t238 = 0.009;
    let t200 = acc2 * t238;
    let t201 = t187 + t200;
    let t202 = t177 + t201;
    let t207 = t202 + t205;
    let t212 = t207 + t210;
    let t129 = t212 / acc3;
    arr256.push(t129);
  }
  return arr256;
}

export function _after_tax(input) {
  let t217 = input["statuses"];
  let t233 = input["income"];
  let t234 = 168600.0;
  let acc1 = Math.min(t233, t234);
  let t235 = 0.062;
  let t187 = acc1 * t235;
  let t236 = 0.0145;
  let t190 = t233 * t236;
  let t191 = t187 + t190;
  let t245 = input["state_rate"];
  let t209 = t233 * t245;
  let t250 = input["local_rate"];
  let t214 = t233 * t250;
  let arr256 = [];
  for (let statuses_i219 = 0; statuses_i219 < t217.length; statuses_i219++) {
    let statuses_el218 = t217[statuses_i219];
    let t220 = input["income"];
    let t221 = statuses_el218["std"];
    let t139 = t220 - t221;
    let t222 = 0;
    let acc0 = Math.max(t139, t222);
    let t223 = statuses_el218["rates"];
    let acc232 = 0.0;
    for (let rates_i225 = 0; rates_i225 < t223.length; rates_i225++) {
      let rates_el224 = t223[rates_i225];
      let t226 = rates_el224["lo"];
      let t149 = acc0 - t226;
      let t227 = rates_el224["hi"];
      let t228 = -1;
      let t159 = t227 == t228;
      let t229 = 100000000000.0;
      let t167 = t159 ? t229 : t227;
      let t173 = t167 - t226;
      let t230 = 0;
      let t174 = Math.min(Math.max(t149, t230), t173);
      let t231 = rates_el224["rate"];
      let t180 = t174 * t231;
      acc232 += t180;
    }
    let t181 = acc232;
    let t239 = input["income"];
    let t240 = statuses_el218["addl_threshold"];
    let t198 = t239 - t240;
    let t241 = 0;
    let acc2 = Math.max(t198, t241);
    let t242 = 0.009;
    let t204 = acc2 * t242;
    let t205 = t191 + t204;
    let t206 = t181 + t205;
    let t211 = t206 + t209;
    let t216 = t211 + t214;
    let t255 = input["income"];
    let t133 = t255 - t216;
    arr256.push(t133);
  }
  return arr256;
}

export function _take_home(input) {
  let t224 = input["statuses"];
  let t240 = input["income"];
  let t241 = 168600.0;
  let acc1 = Math.min(t240, t241);
  let t242 = 0.062;
  let t193 = acc1 * t242;
  let t243 = 0.0145;
  let t196 = t240 * t243;
  let t197 = t193 + t196;
  let t252 = input["state_rate"];
  let t215 = t240 * t252;
  let t257 = input["local_rate"];
  let t220 = t240 * t257;
  let arr264 = [];
  for (let statuses_i226 = 0; statuses_i226 < t224.length; statuses_i226++) {
    let statuses_el225 = t224[statuses_i226];
    let t227 = input["income"];
    let t228 = statuses_el225["std"];
    let t145 = t227 - t228;
    let t229 = 0;
    let acc0 = Math.max(t145, t229);
    let t230 = statuses_el225["rates"];
    let acc239 = 0.0;
    for (let rates_i232 = 0; rates_i232 < t230.length; rates_i232++) {
      let rates_el231 = t230[rates_i232];
      let t233 = rates_el231["lo"];
      let t155 = acc0 - t233;
      let t234 = rates_el231["hi"];
      let t235 = -1;
      let t165 = t234 == t235;
      let t236 = 100000000000.0;
      let t173 = t165 ? t236 : t234;
      let t179 = t173 - t233;
      let t237 = 0;
      let t180 = Math.min(Math.max(t155, t237), t179);
      let t238 = rates_el231["rate"];
      let t186 = t180 * t238;
      acc239 += t186;
    }
    let t187 = acc239;
    let t246 = input["income"];
    let t247 = statuses_el225["addl_threshold"];
    let t204 = t246 - t247;
    let t248 = 0;
    let acc2 = Math.max(t204, t248);
    let t249 = 0.009;
    let t210 = acc2 * t249;
    let t211 = t197 + t210;
    let t212 = t187 + t211;
    let t217 = t212 + t215;
    let t222 = t217 + t220;
    let t262 = input["income"];
    let t223 = t262 - t222;
    let t263 = input["retirement_contrib"];
    let t137 = t223 - t263;
    arr264.push(t137);
  }
  return arr264;
}

export function _summary(input) {
  let t725 = input["statuses"];
  let t742 = input["income"];
  let t743 = 1.0;
  let acc3 = Math.max(t742, t743);
  let t750 = 168600.0;
  let acc5 = Math.min(t742, t750);
  let t751 = 0.062;
  let t323 = acc5 * t751;
  let t752 = 0.0145;
  let t326 = t742 * t752;
  let t327 = t323 + t326;
  let t759 = input["state_rate"];
  let t374 = t742 * t759;
  let t151 = { "marginal": t759, "effective": t759, "tax": t374 };
  let t760 = input["local_rate"];
  let t377 = t742 * t760;
  let t155 = { "marginal": t760, "effective": t760, "tax": t377 };
  let arr773 = [];
  for (let statuses_i727 = 0; statuses_i727 < t725.length; statuses_i727++) {
    let statuses_el726 = t725[statuses_i727];
    let t728 = input["income"];
    let t729 = statuses_el726["std"];
    let t168 = t728 - t729;
    let t730 = 0;
    let acc0 = Math.max(t168, t730);
    let t731 = statuses_el726["rates"];
    let acc740 = 0.0;
    let acc741 = 0.0;
    for (let rates_i733 = 0; rates_i733 < t731.length; rates_i733++) {
      let rates_el732 = t731[rates_i733];
      let t734 = rates_el732["lo"];
      let t178 = acc0 >= t734;
      let t735 = rates_el732["hi"];
      let t736 = -1;
      let t196 = t735 == t736;
      let t737 = 100000000000.0;
      let t204 = t196 ? t737 : t735;
      let t205 = acc0 < t204;
      let t206 = t178 && t205;
      let t738 = rates_el732["rate"];
      let t739 = 0;
      let t214 = t206 ? t738 : t739;
      acc740 += t214;
      let t231 = acc0 - t734;
      let t255 = t204 - t734;
      let t256 = Math.min(Math.max(t231, t739), t255);
      let t262 = t256 * t738;
      acc741 += t262;
    }
    let t215 = acc740;
    let t263 = acc741;
    let t269 = t263 / acc3;
    let t144 = { "marginal": t215, "effective": t269, "tax": t263 };
    let t755 = input["income"];
    let t756 = statuses_el726["addl_threshold"];
    let t334 = t755 - t756;
    let t757 = 0;
    let acc6 = Math.max(t334, t757);
    let t758 = 0.009;
    let t340 = acc6 * t758;
    let t341 = t327 + t340;
    let t347 = t341 / acc3;
    let t147 = { "effective": t347, "tax": t341 };
    let t450 = t263 + t341;
    let t455 = t450 + t374;
    let t460 = t455 + t377;
    let t466 = t460 / acc3;
    let t158 = { "effective": t466, "tax": t460 };
    let t766 = input["income"];
    let t635 = t766 - t460;
    let t767 = input["retirement_contrib"];
    let t724 = t635 - t767;
    let t768 = statuses_el726["name"];
    let t162 = { "filing_status": t768, "federal": t144, "fica": t147, "state": t151, "local": t155, "total": t158, "after_tax": t635, "retirement_contrib": t767, "take_home": t724 };
    arr773.push(t162);
  }
  return arr773;
}

