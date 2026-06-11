export function _name_len(input) {
  let t3 = input["name"];
  let t2 = t3.length;
  return t2;
}

export function _items_count(input) {
  let t5 = input["items"];
  let t4 = t5.length;
  return t4;
}

export function _summary(input) {
  let t12 = input["name"];
  let t9 = t12.length;
  let t13 = input["items"];
  let t11 = t13.length;
  let t7 = { "name_length": t9, "item_count": t11 };
  return t7;
}

