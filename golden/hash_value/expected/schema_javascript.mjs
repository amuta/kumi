export function _users(input) {
  let out = [];
  let t1 = input["users"];
  t1.forEach((users_el_2, users_i_3) => {
    let t4 = users_el_2["name"];
    let t5 = users_el_2["state"];
    let t6 = {
      "name": t4,
      "state": t5
    };
    out.push(t6);
  });
  return out;
}

export function _is_john(input) {
  let out = [];
  let t7 = input["users"];
  const t11 = "John";
  t7.forEach((users_el_8, users_i_9) => {
    let t10 = users_el_8["name"];
    let t12 = t10 == t11;
    out.push(t12);
  });
  return out;
}

export function _john_user(input) {
  let out = [];
  let t13 = input["users"];
  const t22 = "John";
  const t18 = "NOT_JOHN";
  t13.forEach((users_el_14, users_i_15) => {
    let t21 = users_el_14["name"];
    let t26 = users_el_14["state"];
    let t23 = t21 == t22;
    let t27 = {
      "name": t21,
      "state": t26
    };
    let t19 = t23 ? t27 : t18;
    out.push(t19);
  });
  return out;
}

