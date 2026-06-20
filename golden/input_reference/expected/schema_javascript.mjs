export function _app_name(input) {
  let t3 = input["config"];
  let t4 = t3["app_name"];
  return t4;
}

export function _all_flags(input) {
  let t6 = input["config"];
  let t7 = t6["feature_flags"];
  let arr11 = [];
  for (let feature_flags_i9 = 0; feature_flags_i9 < t7.length; feature_flags_i9++) {
    let feature_flags_el8 = t7[feature_flags_i9];
    arr11.push(feature_flags_el8);
  }
  return arr11;
}

export function _server_hostnames(input) {
  let t10 = input["config"];
  let t11 = t10["servers"];
  let arr16 = [];
  for (let servers_i13 = 0; servers_i13 < t11.length; servers_i13++) {
    let servers_el12 = t11[servers_i13];
    let t14 = servers_el12["hostname"];
    arr16.push(t14);
  }
  return arr16;
}

export function _server_count(input) {
  let t13 = input["config"];
  let t14 = t13["servers"];
  let t12 = t14.length;
  return t12;
}

export function _total_ports(input) {
  let t18 = input["config"];
  let t19 = t18["servers"];
  let acc23 = 0;
  for (let servers_i21 = 0; servers_i21 < t19.length; servers_i21++) {
    let servers_el20 = t19[servers_i21];
    let t22 = servers_el20["port"];
    acc23 += t22;
  }
  return acc23;
}

