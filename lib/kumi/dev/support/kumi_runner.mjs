// run_kumi_direct.mjs
import fs from "fs";
import path from "path";
import { fileURLToPath } from 'url';

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

    // Setup global namespace for imported schemas
    const sharedDir = path.resolve(path.dirname(modulePath), '../../_shared');
    globalThis.GoldenSchemas = {};

    // Load all available shared schema modules
    const sharedSchemas = ['tax', 'discount', 'compound'];
    for (const schemaName of sharedSchemas) {
      try {
        const module = await import(path.resolve(sharedDir, `${schemaName}_javascript.mjs`));
        // Convert snake_case to PascalCase for class name
        const className = schemaName.split('_').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join('');
        globalThis.GoldenSchemas[className] = module[className];
      } catch (e) {
        // Shared modules may not exist for all schemas
      }
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
