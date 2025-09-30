import fs from 'fs';
import path from 'path';

// A simple runner to execute a Kumi-generated JS module.
// It imports the module, instantiates it with input data,
// runs the specified declarations, and prints the results to stdout as JSON.
async function main() {
  try {
    const modulePath = path.resolve(process.argv[2]);
    const inputPath = path.resolve(process.argv[3]);
    const declsToRun = process.argv[4].split(',');

    // Dynamically import the user-provided ES module.
    const { KumiCompiledModule } = await import(modulePath);

    // Load input data.
    const inputData = JSON.parse(fs.readFileSync(inputPath, 'utf-8'));

    const instance = KumiCompiledModule.from(inputData);
    const results = {};

    for (const decl of declsToRun) {
      if (decl) { // Handles potential trailing commas.
        results[decl] = instance.get(decl);
      }
    }

    // Output results as a single JSON string to stdout for the Ruby process.
    console.log(JSON.stringify(results));
  } catch (error) {
    // Write error to stderr so the calling process can see it and fail.
    console.error(`JS Runner Error: ${error.message}\n${error.stack}`);
    process.exit(1);
  }
}

main();