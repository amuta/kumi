// run_kumi_direct.mjs
import fs from "fs";
import path from "path";

async function main() {
  try {
    const modulePath = path.resolve(process.argv[2]);
    const inputPath  = path.resolve(process.argv[3]);
    const declsToRun = (process.argv[4] || "")
      .split(",")
      .map(s => s.trim())
      .filter(Boolean);

    if (!modulePath || !inputPath || declsToRun.length === 0) {
      console.error("Usage: node run_kumi_direct.mjs <module.mjs> <input.json> <decl1,decl2,...>");
      process.exit(2);
    }

    const mod = await import(modulePath);
    const input = JSON.parse(fs.readFileSync(inputPath, "utf-8"));

    const results = {};
    for (const decl of declsToRun) {
      const fnName = `_${decl}`;
      const fn = mod[fnName];
      if (typeof fn !== "function") {
        throw new Error(`Missing export ${fnName}`);
      }
      results[decl] = fn(input);
    }

    console.log(JSON.stringify(results));
  } catch (err) {
    console.error(`JS Runner Error: ${err?.message}\n${err?.stack}`);
    process.exit(1);
  }
}

main();
