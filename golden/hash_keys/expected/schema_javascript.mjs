export function _meta(input) {
  const t1 = "grid2d";
  let t2 = input["width"];
  let t3 = input["height"];
  let t4 = {
    "width": t2,
    "height": t3
  };
  const t5 = "random";
  const t6 = 0.3;
  let t7 = {
    "kind": t5,
    "density": t6
  };
  const t8 = 10;
  const t9 = "#0f1219";
  const t10 = "#10b981";
  let t11 = {
    "0": t9,
    "1": t10
  };
  let t12 = {
    "cellSize": t8,
    "palette": t11
  };
  let t13 = {
    "render": t1,
    "size": t4,
    "prefill": t7,
    "ui": t12
  };
  return t13;
}

