export function _price_with_bonus(input) {
  let t6 = input["items"];
  let arr11 = [];
  for (let items_i8 = 0; items_i8 < t6.length; items_i8++) {
    let items_el7 = t6[items_i8];
    let t9 = items_el7["price"];
    let t10 = 10;
    let t5 = [t9, t10];
    arr11.push(t5);
  }
  return arr11;
}

