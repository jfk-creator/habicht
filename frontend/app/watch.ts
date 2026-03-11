import { watch } from "node:fs";

const rebuild = async () => {
  const build = await Bun.build({
    entrypoints: ["./src/login.ts", "./src/registration.ts", "./src/data.ts"], // Add your files here
    outdir: "./dist",
  });

  if (!build.success) {
    console.error("Build failed", build.logs);
  } else {
    console.log("✅ Rebuilt independent files");
  }
};

// Initial build
await rebuild();

// Watch the directory
watch("./src", { recursive: true }, (event, filename) => {
  console.log(`Detected change in ${filename}...`);
  rebuild();
});
