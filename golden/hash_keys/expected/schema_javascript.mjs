export function _meta(input) {
  let t2 = input["width"];
  let t3 = input["height"];
  let t4 = {
    "width": t2,
    "height": t3
  };
  let t7 = {
    "kind": "random",
    "density": 0.3
  };
  let t11 = {
    "0": "#0f1219",
    "1": "#10b981"
  };
  let t12 = {
    "cellSize": 10,
    "palette": t11
  };
  let t13 = {
    "render": "grid2d",
    "size": t4,
    "prefill": t7,
    "ui": t12
  };
  return t13;
}

