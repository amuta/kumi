export function _price_with_bonus(input) {
  let out = [];
  let t1 = input["items"];
  t1.forEach((items_el_2, items_i_3) => {
    let t4 = items_el_2["price"];
    let t6 = [t4, 10];
    out.push(t6);
  });
  return out;
}

