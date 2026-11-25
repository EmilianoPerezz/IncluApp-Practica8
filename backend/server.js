import express from "express";
import dotenv from "dotenv";
import { DatabaseSync } from "node:sqlite";
import { GoogleGenAI } from "@google/genai";

dotenv.config();

const app = express();
app.use(express.json());

const PORT = Number(process.env.PORT || 3000);

const db = new DatabaseSync("incluapp.db");

db.exec(`
  CREATE TABLE IF NOT EXISTS incidencias (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    descripcion TEXT NOT NULL,
    ubicacion TEXT,
    analisis_ia TEXT NOT NULL,
    fecha TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )
`);

const ai = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY
});

function esperar(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function generarAnalisisConReintentos(prompt) {
  const maxIntentos = 3;

  for (let intento = 1; intento <= maxIntentos; intento++) {
    try {
      const result = await ai.models.generateContent({
        model: process.env.GEMINI_MODEL || "gemini-3.8-flash",
        contents: prompt
      });
      return result.text || "No se recibió un análisis de Gemini.";
    } catch (error) {
      const saturado = error?.status === 503;
      const esUltimoIntento = intento === maxIntentos;

      if (saturado && !esUltimoIntento) {
        console.log(`Gemini está saturado, reintentando (${intento}/${maxIntentos})...`);
        await esperar(2000 * intento);
      } else {
        throw error;
      }
    }
  }
}

app.get("/api/health", (req, res) => {
  res.json({ estado: "activo", servicio: "IncluApp API" });
});

app.get("/api/incidencias", (req, res) => {
  const rows = db.prepare(
    "SELECT * FROM incidencias ORDER BY id DESC"
  ).all();
  res.json(rows);
});

app.post("/api/incidencias", async (req, res) => {
  try {
    const { descripcion, ubicacion = "" } = req.body;

    if (typeof descripcion !== "string" ||
        descripcion.trim().length < 10) {
      return res.status(400).json({
        error: "La descripción debe contener al menos 10 caracteres."
      });
    }

    const prompt = `
Analiza esta situación relacionada con accesibilidad e inclusión.
Devuelve una respuesta breve en español con:
1. Tipo de barrera o problema.
2. Nivel de prioridad (baja, media o alta).
3. Recomendación de atención.
No inventes datos que no estén en la descripción.
Aclara que es una orientación automatizada y requiere validación humana.

Descripción: ${descripcion.trim()}
Ubicación: ${String(ubicacion).trim() || "No especificada"}
`;

    let analisis;
    try {
      analisis = await generarAnalisisConReintentos(prompt);
    } catch (error) {
      console.error("Gemini no respondió, se guarda sin análisis:", error.status);
      analisis = "Análisis no disponible por el momento: el servicio de Gemini no respondió. El reporte quedó registrado y requiere revisión humana.";
    }

    const insert = db.prepare(`
      INSERT INTO incidencias (descripcion, ubicacion, analisis_ia)
      VALUES (?, ?, ?)
    `);
    const saved = insert.run(
      descripcion.trim(),
      String(ubicacion).trim(),
      analisis
    );

    res.status(201).json({
      id: Number(saved.lastInsertRowid),
      descripcion: descripcion.trim(),
      ubicacion: String(ubicacion).trim(),
      analisis_ia: analisis
    });
  } catch (error) {
    console.error("Error al registrar incidencia:", error);
    res.status(502).json({
      error: "No fue posible procesar la solicitud. Revisa Gemini y el servidor."
    });
  }
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`IncluApp API disponible en el puerto ${PORT}`);
});
