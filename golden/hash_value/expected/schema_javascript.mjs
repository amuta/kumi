export function _users(input) {
  let t8 = input["users"];
  let arr13 = [];
  for (let users_i10 = 0; users_i10 < t8.length; users_i10++) {
    let users_el9 = t8[users_i10];
    let t11 = users_el9["name"];
    let t12 = users_el9["state"];
    let t7 = { "name": t11, "state": t12 };
    arr13.push(t7);
  }
  return arr13;
}

export function _is_john(input) {
  let t14 = input["users"];
  let arr19 = [];
  for (let users_i16 = 0; users_i16 < t14.length; users_i16++) {
    let users_el15 = t14[users_i16];
    let t17 = users_el15["name"];
    let t18 = "John";
    let t13 = t17 == t18;
    arr19.push(t13);
  }
  return arr19;
}

export function _john_user(input) {
  let t32 = input["users"];
  let arr39 = [];
  for (let users_i34 = 0; users_i34 < t32.length; users_i34++) {
    let users_el33 = t32[users_i34];
    let t35 = users_el33["name"];
    let t36 = "John";
    let t24 = t35 == t36;
    let t37 = users_el33["state"];
    let t31 = { "name": t35, "state": t37 };
    let t38 = "NOT_JOHN";
    let t18 = t24 ? t31 : t38;
    arr39.push(t18);
  }
  return arr39;
}

