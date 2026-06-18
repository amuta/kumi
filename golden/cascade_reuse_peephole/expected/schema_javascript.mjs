export function _b1(input) {
  let t4 = input["birth_year"];
  let t5 = 1937;
  let t3 = t4 <= t5;
  return t3;
}

export function _b2(input) {
  let t11 = input["birth_year"];
  let t12 = 1938;
  let t6 = t11 >= t12;
  let t13 = 1942;
  let t9 = t11 <= t13;
  let t10 = t6 && t9;
  return t10;
}

export function _b3(input) {
  let t18 = input["birth_year"];
  let t19 = 1943;
  let t13 = t18 >= t19;
  let t20 = 1954;
  let t16 = t18 <= t20;
  let t17 = t13 && t16;
  return t17;
}

export function _b4(input) {
  let t25 = input["birth_year"];
  let t26 = 1955;
  let t20 = t25 >= t26;
  let t27 = 1959;
  let t23 = t25 <= t27;
  let t24 = t20 && t23;
  return t24;
}

export function _b5(input) {
  let t28 = input["birth_year"];
  let t29 = 1960;
  let t27 = t28 >= t29;
  return t27;
}

export function _full_retirement_age(input) {
  let t84 = input["birth_year"];
  let t85 = 1937;
  let t62 = t84 <= t85;
  let t86 = 1938;
  let t65 = t84 >= t86;
  let t87 = 1942;
  let t68 = t84 <= t87;
  let t69 = t65 && t68;
  let t34 = t84 - t85;
  let t88 = 2.0;
  let t89 = 12.0;
  let t37 = t88 / t89;
  let t38 = t34 * t37;
  let t90 = 65.0;
  let t39 = t90 + t38;
  let t91 = 1943;
  let t72 = t84 >= t91;
  let t92 = 1954;
  let t75 = t84 <= t92;
  let t76 = t72 && t75;
  let t93 = 1955;
  let t79 = t84 >= t93;
  let t94 = 1959;
  let t82 = t84 <= t94;
  let t83 = t79 && t82;
  let t46 = t84 - t92;
  let t50 = t46 * t37;
  let t95 = 66.0;
  let t51 = t95 + t50;
  let t96 = 67.0;
  let t56 = t83 ? t51 : t96;
  let t57 = t76 ? t95 : t56;
  let t58 = t69 ? t39 : t57;
  let t59 = t62 ? t90 : t58;
  return t59;
}

export function _months_delayed(input) {
  let t122 = input["birth_year"];
  let t123 = 1937;
  let t70 = t122 <= t123;
  let t124 = 1938;
  let t74 = t122 >= t124;
  let t125 = 1942;
  let t77 = t122 <= t125;
  let t78 = t74 && t77;
  let t82 = t122 - t123;
  let t126 = 2.0;
  let t127 = 12.0;
  let t85 = t126 / t127;
  let t86 = t82 * t85;
  let t128 = 65.0;
  let t87 = t128 + t86;
  let t129 = 1943;
  let t90 = t122 >= t129;
  let t130 = 1954;
  let t93 = t122 <= t130;
  let t94 = t90 && t93;
  let t131 = 1955;
  let t98 = t122 >= t131;
  let t132 = 1959;
  let t101 = t122 <= t132;
  let t102 = t98 && t101;
  let t106 = t122 - t130;
  let t110 = t106 * t85;
  let t133 = 66.0;
  let t111 = t133 + t110;
  let t134 = 67.0;
  let t118 = t102 ? t111 : t134;
  let t119 = t94 ? t133 : t118;
  let t120 = t78 ? t87 : t119;
  let t121 = t70 ? t128 : t120;
  let t135 = input["claiming_age"];
  let t64 = t135 - t121;
  let t136 = 12;
  let t65 = t136 * t64;
  let t137 = 0;
  let acc0 = Math.max(t137, t65);
  return acc0;
}

export function _months_early(input) {
  let t130 = input["birth_year"];
  let t131 = 1937;
  let t78 = t130 <= t131;
  let t132 = 1938;
  let t82 = t130 >= t132;
  let t133 = 1942;
  let t85 = t130 <= t133;
  let t86 = t82 && t85;
  let t90 = t130 - t131;
  let t134 = 2.0;
  let t135 = 12.0;
  let t93 = t134 / t135;
  let t94 = t90 * t93;
  let t136 = 65.0;
  let t95 = t136 + t94;
  let t137 = 1943;
  let t98 = t130 >= t137;
  let t138 = 1954;
  let t101 = t130 <= t138;
  let t102 = t98 && t101;
  let t139 = 1955;
  let t106 = t130 >= t139;
  let t140 = 1959;
  let t109 = t130 <= t140;
  let t110 = t106 && t109;
  let t114 = t130 - t138;
  let t118 = t114 * t93;
  let t141 = 66.0;
  let t119 = t141 + t118;
  let t142 = 67.0;
  let t126 = t110 ? t119 : t142;
  let t127 = t102 ? t141 : t126;
  let t128 = t86 ? t95 : t127;
  let t129 = t78 ? t136 : t128;
  let t143 = input["claiming_age"];
  let t72 = t129 - t143;
  let t144 = 12;
  let t73 = t144 * t72;
  let t145 = 0;
  let acc0 = Math.max(t145, t73);
  return acc0;
}

export function _months_early_first_36(input) {
  let t139 = input["birth_year"];
  let t140 = 1937;
  let t84 = t139 <= t140;
  let t141 = 1938;
  let t88 = t139 >= t141;
  let t142 = 1942;
  let t91 = t139 <= t142;
  let t92 = t88 && t91;
  let t96 = t139 - t140;
  let t143 = 2.0;
  let t144 = 12.0;
  let t99 = t143 / t144;
  let t100 = t96 * t99;
  let t145 = 65.0;
  let t101 = t145 + t100;
  let t146 = 1943;
  let t104 = t139 >= t146;
  let t147 = 1954;
  let t107 = t139 <= t147;
  let t108 = t104 && t107;
  let t148 = 1955;
  let t112 = t139 >= t148;
  let t149 = 1959;
  let t115 = t139 <= t149;
  let t116 = t112 && t115;
  let t120 = t139 - t147;
  let t124 = t120 * t99;
  let t150 = 66.0;
  let t125 = t150 + t124;
  let t151 = 67.0;
  let t132 = t116 ? t125 : t151;
  let t133 = t108 ? t150 : t132;
  let t134 = t92 ? t101 : t133;
  let t135 = t84 ? t145 : t134;
  let t152 = input["claiming_age"];
  let t137 = t135 - t152;
  let t153 = 12;
  let t138 = t153 * t137;
  let t154 = 0;
  let acc0 = Math.max(t154, t138);
  let t155 = 36;
  let acc1 = Math.min(t155, acc0);
  return acc1;
}

export function _months_early_additional(input) {
  let t148 = input["birth_year"];
  let t149 = 1937;
  let t93 = t148 <= t149;
  let t150 = 1938;
  let t97 = t148 >= t150;
  let t151 = 1942;
  let t100 = t148 <= t151;
  let t101 = t97 && t100;
  let t105 = t148 - t149;
  let t152 = 2.0;
  let t153 = 12.0;
  let t108 = t152 / t153;
  let t109 = t105 * t108;
  let t154 = 65.0;
  let t110 = t154 + t109;
  let t155 = 1943;
  let t113 = t148 >= t155;
  let t156 = 1954;
  let t116 = t148 <= t156;
  let t117 = t113 && t116;
  let t157 = 1955;
  let t121 = t148 >= t157;
  let t158 = 1959;
  let t124 = t148 <= t158;
  let t125 = t121 && t124;
  let t129 = t148 - t156;
  let t133 = t129 * t108;
  let t159 = 66.0;
  let t134 = t159 + t133;
  let t160 = 67.0;
  let t141 = t125 ? t134 : t160;
  let t142 = t117 ? t159 : t141;
  let t143 = t101 ? t110 : t142;
  let t144 = t93 ? t154 : t143;
  let t161 = input["claiming_age"];
  let t146 = t144 - t161;
  let t162 = 12;
  let t147 = t162 * t146;
  let t163 = 0;
  let acc0 = Math.max(t163, t147);
  let t164 = 36;
  let t83 = acc0 - t164;
  let acc1 = Math.max(t163, t83);
  let t165 = 24;
  let acc2 = Math.min(acc1, t165);
  return acc2;
}

export function _adj(input) {
  let t306 = input["birth_year"];
  let t307 = 1937;
  let t119 = t306 <= t307;
  let t308 = 1938;
  let t123 = t306 >= t308;
  let t309 = 1942;
  let t126 = t306 <= t309;
  let t127 = t123 && t126;
  let t131 = t306 - t307;
  let t310 = 2.0;
  let t311 = 12.0;
  let t134 = t310 / t311;
  let t135 = t131 * t134;
  let t312 = 65.0;
  let t136 = t312 + t135;
  let t313 = 1943;
  let t139 = t306 >= t313;
  let t314 = 1954;
  let t142 = t306 <= t314;
  let t143 = t139 && t142;
  let t315 = 1955;
  let t147 = t306 >= t315;
  let t316 = 1959;
  let t150 = t306 <= t316;
  let t151 = t147 && t150;
  let t155 = t306 - t314;
  let t159 = t155 * t134;
  let t317 = 66.0;
  let t160 = t317 + t159;
  let t318 = 67.0;
  let t167 = t151 ? t160 : t318;
  let t168 = t143 ? t317 : t167;
  let t169 = t127 ? t136 : t168;
  let t170 = t119 ? t312 : t169;
  let t319 = input["claiming_age"];
  let t172 = t170 - t319;
  let t320 = 12;
  let t173 = t320 * t172;
  let t321 = 0;
  let acc0 = Math.max(t321, t173);
  let t322 = 36;
  let acc1 = Math.min(t322, acc0);
  let t323 = -5.0;
  let t324 = 9.0;
  let t93 = t323 / t324;
  let t325 = 0.01;
  let t95 = t93 * t325;
  let t96 = acc1 * t95;
  let t326 = 1.0;
  let t97 = t326 + t96;
  let t241 = acc0 - t322;
  let acc3 = Math.max(t321, t241);
  let t327 = 24;
  let acc4 = Math.min(acc3, t327);
  let t101 = t323 / t311;
  let t103 = t101 * t325;
  let t104 = acc4 * t103;
  let t105 = t97 + t104;
  let t304 = t319 - t170;
  let t305 = t320 * t304;
  let acc5 = Math.max(t321, t305);
  let t328 = 3.0;
  let t109 = t310 / t328;
  let t111 = t109 * t325;
  let t112 = acc5 * t111;
  let t113 = t105 + t112;
  return t113;
}

