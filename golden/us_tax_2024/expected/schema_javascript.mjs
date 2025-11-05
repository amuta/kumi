export function _summary(input) {
  let out = [];
  let t974 = input["income"];
  let t976 = [t974, 168600.0];
  let t977 = Math.min(...t976);
  let t979 = t977 * 0.062;
  let t982 = t974 * 0.0145;
  let t1032 = input["state_rate"];
  let t1033 = t974 * t1032;
  let t1035 = input["local_rate"];
  let t1036 = t974 * t1035;
  let t181 = input["statuses"];
  let t971 = t979 + t982;
  let t195 = {
    "marginal": t1032,
    "effective": t1032,
    "tax": t1033
  };
  let t199 = {
    "marginal": t1035,
    "effective": t1035,
    "tax": t1036
  };
  let t204 = input["retirement_contrib"];
  let t858 = [t974, 1.0];
  let t859 = Math.max(...t858);
  t181.forEach((statuses_el_182, statuses_i_183) => {
    let t184 = statuses_el_182["name"];
    let t822 = statuses_el_182["std"];
    let acc802 = 0.0;
    let t803 = statuses_el_182["rates"];
    let acc863 = 0.0;
    let acc913 = 0.0;
    let t985 = statuses_el_182["addl_threshold"];
    let acc1039 = 0.0;
    let acc1127 = 0.0;
    let acc1219 = 0.0;
    let acc1315 = 0.0;
    let t823 = t974 - t822;
    let t986 = t974 - t985;
    let t825 = [t823, 0];
    let t988 = [t986, 0];
    let t826 = Math.max(...t825);
    let t989 = Math.max(...t988);
    t803.forEach((t804, t805) => {
      let t829 = t804["lo"];
      let t815 = t826 >= t829;
      let t847 = t804["hi"];
      let t841 = t847 == -1;
      let t844 = t841 ? 100000000000.0 : t847;
      let t818 = t826 < t844;
      let t819 = t815 && t818;
      let t853 = t804["rate"];
      let t809 = t819 ? t853 : 0;
      acc802 += t809;
    });
    let t991 = t989 * 0.009;
    t803.forEach((t865, t866) => {
      let t890 = t865["lo"];
      let t875 = t826 - t890;
      let t901 = t865["hi"];
      let t895 = t901 == -1;
      let t898 = t895 ? 100000000000.0 : t901;
      let t879 = t898 - t890;
      let t880 = Math.min(Math.max(t875, 0), t879);
      let t910 = t865["rate"];
      let t869 = t880 * t910;
      acc863 += t869;
      acc913 += t869;
      acc1039 += t869;
      acc1127 += t869;
      acc1219 += t869;
      acc1315 += t869;
    });
    let t973 = t971 + t991;
    let t967 = t973 / t859;
    let t860 = acc863 / t859;
    let t1028 = acc1039 + t973;
    let t1116 = acc1127 + t973;
    let t1208 = acc1219 + t973;
    let t1304 = acc1315 + t973;
    let t191 = {
      "effective": t967,
      "tax": t973
    };
    let t188 = {
      "marginal": acc802,
      "effective": t860,
      "tax": acc913
    };
    let t1029 = t1028 + t1033;
    let t1117 = t1116 + t1033;
    let t1209 = t1208 + t1033;
    let t1305 = t1304 + t1033;
    let t1030 = t1029 + t1036;
    let t1118 = t1117 + t1036;
    let t1210 = t1209 + t1036;
    let t1306 = t1305 + t1036;
    let t1022 = t1030 / t859;
    let t1202 = t974 - t1210;
    let t1298 = t974 - t1306;
    let t202 = {
      "effective": t1022,
      "tax": t1118
    };
    let t1294 = t1298 - t204;
    let t206 = {
      "filing_status": t184,
      "federal": t188,
      "fica": t191,
      "state": t195,
      "local": t199,
      "total": t202,
      "after_tax": t1202,
      "retirement_contrib": t204,
      "take_home": t1294
    };
    out.push(t206);
  });
  return out;
}

