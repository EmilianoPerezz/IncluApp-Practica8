const url = `https://generativelanguage.googleapis.com/v1beta/models?key=${process.env.GEMINI_API_KEY}`;
const res = await fetch(url);
const data = await res.json();

if (!data.models) {
  console.log("Error:", JSON.stringify(data));
} else {
  const lista = data.models
    .filter(m => m.supportedGenerationMethods.includes("generateContent"))
    .map(m => m.name.replace("models/", ""));
  console.log(lista.join("\n"));
}