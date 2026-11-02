// ----------------------------------------------------------------------------
// DATOS SINTÉTICOS DE EJEMPLO — no son datos reales de ninguna operación.
// Genera 14 días de datos por hora con el mismo formato que entrega el
// workflow n8n (ver n8n/workflow.json y sql/), para que el dashboard funcione
// abriendo index.html directamente en el navegador o en GitHub Pages.
//
// Para usar datos reales: elimina el <script src="data/sample-data.js"> de
// index.html y deja un archivo data/volumetria.json servido por HTTP.
// ----------------------------------------------------------------------------
(function () {
  // Generador pseudoaleatorio con semilla fija (resultado reproducible)
  var seed = 42;
  function rnd() { seed = (seed * 1664525 + 1013904223) % 4294967296; return seed / 4294967296; }
  function between(a, b) { return a + (b - a) * rnd(); }

  // área: [unidades/hora, litros/unidad, ratio SKU/unidades, binfullness %]
  var AREAS = {
    MZ0: [3000, 2.2, 0.05, 64], MZ1: [1900, 3.8, 0.15, 60], MZ2: [1500, 3.0, 0.10, 55],
    MZ3: [1200, 2.6, 0.10, 58], HV3: [600, 8.0, 0.20, 50],
    BL0: [30, 43, 0.03, 69], HS: [350, 30, 0.10, 44], RK0: [120, 51, 0.08, 58], RS0: [700, 6.2, 0.04, 72],
    CI_TOT: [8000, 3.7, 0.07, null], CI_NOT: [650, 36, 0.07, null],
    DCI_TOT: [2400, 3.8, 0.03, null], DCI_NOT: [170, 41, 0.03, null]
  };

  var end = new Date(2026, 9, 29, 23, 0, 0); // último dato: 29-10-2026 23:00
  var rows = [];
  function pad(n) { return (n < 10 ? '0' : '') + n; }

  for (var h = 0; h < 14 * 24; h++) {
    var t = new Date(end.getTime() - h * 3600000);
    var fecha = t.getFullYear() + '-' + pad(t.getMonth() + 1) + '-' + pad(t.getDate());
    var actividad = (t.getHours() >= 6) ? 1 : 0.25; // menos movimiento de madrugada
    Object.keys(AREAS).forEach(function (area) {
      if (rnd() < 0.08) return; // algunas horas sin movimiento
      var c = AREAS[area];
      var un = Math.max(1, Math.round(c[0] * actividad * between(0.3, 1.6)));
      var lpu = +(c[1] * between(0.5, 1.7)).toFixed(4);
      rows.push({
        FECHA: fecha,
        HORA: t.getHours(),
        AREA: area,
        SKUs_Distintos: Math.max(1, Math.round(un * c[2] * between(0.6, 1.4))),
        Cantidad_Total_Unidades: un,
        Volumen_Total_Litros: +(un * lpu).toFixed(2),
        Volumetria_Litros_Por_Unidad: lpu,
        Binfullness: c[3] === null ? null : +(c[3] * between(0.9, 1.1)).toFixed(1)
      });
    });
  }

  window.SAMPLE_DATA = { volumetria: rows, toteabilidad: [] };
})();
