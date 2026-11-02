-- Nodo n8n: VOLUMETRIA1
-- Une putaway + checkin + DCI y entrega las filas que consume el dashboard

-- ================================================================
-- N8N READ QUERY v7 — versión liviana (sin CUBING)
-- SKUs totales por hora, split estimado con PCT_TOTEABLE
-- ================================================================
WITH
-- SKUs distintos por hora — CHECKIN (sin join a tabla de cubing)
SKU_CHK AS (
  SELECT
    DATE(`your-project.udf.FN_TIMEZONE`('MLC', m.AUD_INS_DTTM))              AS FECHA,
    EXTRACT(HOUR FROM `your-project.udf.FN_TIMEZONE`('MLC', m.AUD_INS_DTTM)) AS HORA,
    COUNT(DISTINCT m.INVENTORY_ID)                                                        AS N_SKUS
  FROM `your-project.source.STOCK_MOVEMENTS` m
  WHERE m.WAREHOUSE_ID = 'CD-01' AND m.FBM_REASON_PROCESS = 'inbound'
    AND m.ADDRESS_FROM IS NULL AND m.ADDRESS_TO LIKE 'MU-%'
    AND m.AUD_INS_DTTM >= DATETIME(TIMESTAMP(DATE_SUB(CURRENT_DATE('America/Santiago'), INTERVAL 14 DAY), 'America/Santiago'))
    AND m.AUD_INS_DTTM <  DATETIME(TIMESTAMP(DATE_ADD(CURRENT_DATE('America/Santiago'), INTERVAL  1 DAY), 'America/Santiago'))
  GROUP BY FECHA, HORA
),
-- Operadores DCI
OPS_DCI AS (
  SELECT DISTINCT CAST(OPERATOR_ID AS STRING) AS OPERATOR_ID, DATE(START_DATE) AS FECHA
  FROM `your-project.source.OPERATOR_PRODUCTIVITY`
  WHERE AREA = 'inbound' AND PROCESS = 'direct_checkin'
    AND DATE(START_DATE) >= DATE_SUB(CURRENT_DATE('America/Santiago'), INTERVAL 14 DAY)
    AND LOGISTIC_CENTER_ID = 'CD-01' AND SITE_ID = 'MLC'
),
-- SKUs distintos por hora — DCI (solo operadores DCI)
SKU_DCI AS (
  SELECT
    DATE(`your-project.udf.FN_TIMEZONE`('MLC', m.AUD_INS_DTTM))              AS FECHA,
    EXTRACT(HOUR FROM `your-project.udf.FN_TIMEZONE`('MLC', m.AUD_INS_DTTM)) AS HORA,
    COUNT(DISTINCT m.INVENTORY_ID)                                                        AS N_SKUS
  FROM `your-project.source.STOCK_MOVEMENTS` m
  INNER JOIN OPS_DCI ops
    ON ops.OPERATOR_ID = CAST(m.FBM_USER_ID AS STRING)
   AND ops.FECHA = DATE(`your-project.udf.FN_TIMEZONE`('MLC', m.AUD_INS_DTTM))
  WHERE m.WAREHOUSE_ID = 'CD-01' AND m.FBM_REASON_PROCESS = 'inbound'
    AND m.ADDRESS_FROM IS NULL AND m.ADDRESS_TO LIKE 'MU-%'
    AND m.AUD_INS_DTTM >= DATETIME(TIMESTAMP(DATE_SUB(CURRENT_DATE('America/Santiago'), INTERVAL 14 DAY), 'America/Santiago'))
    AND m.AUD_INS_DTTM <  DATETIME(TIMESTAMP(DATE_ADD(CURRENT_DATE('America/Santiago'), INTERVAL  1 DAY), 'America/Santiago'))
  GROUP BY FECHA, HORA
),
base AS (
  -- PUTAWAY (sin cambios)
  SELECT
    FORMAT_DATE('%Y-%m-%d', FECHA)         AS FECHA,
    HORA, AREA, SKUs_Distintos,
    Cantidad_Total_Unidades,
    ROUND(Volumen_Total_Litros, 2)         AS Volumen_Total_Litros,
    ROUND(Volumetria_Litros_Por_Unidad, 4) AS Volumetria_Litros_Por_Unidad,
    Binfullness
  FROM `your-project.analytics.VOLUMETRIA_SEMANA`
  UNION ALL
  -- CI_TOT
  SELECT
    FORMAT_DATE('%Y-%m-%d', ch.FECHA) AS FECHA, ch.HORA, 'CI_TOT' AS AREA,
    CAST(ROUND(COALESCE(sk.N_SKUS,0) * COALESCE(ch.PCT_TOTEABLE,0) / 100.0) AS INT64)   AS SKUs_Distintos,
    CAST(ch.UDS_TOTEABLE AS INT64)                                                        AS Cantidad_Total_Unidades,
    ROUND(CAST(ch.UDS_TOTEABLE AS FLOAT64) * COALESCE(ch.L_POR_UD_TOTEABLE,0),2)         AS Volumen_Total_Litros,
    ROUND(ch.L_POR_UD_TOTEABLE, 4)                                                        AS Volumetria_Litros_Por_Unidad,
    NULL AS Binfullness
  FROM `your-project.analytics.CHECKIN_HORA` ch
  LEFT JOIN SKU_CHK sk ON sk.FECHA = ch.FECHA AND sk.HORA = ch.HORA
  UNION ALL
  -- CI_NOT
  SELECT
    FORMAT_DATE('%Y-%m-%d', ch.FECHA) AS FECHA, ch.HORA, 'CI_NOT' AS AREA,
    CAST(ROUND(COALESCE(sk.N_SKUS,0) * (1.0 - COALESCE(ch.PCT_TOTEABLE,0)/100.0)) AS INT64) AS SKUs_Distintos,
    CAST(ch.UDS_NO_TOTEABLE AS INT64)                                                         AS Cantidad_Total_Unidades,
    ROUND(CAST(ch.UDS_NO_TOTEABLE AS FLOAT64) * COALESCE(ch.L_POR_UD_NO_TOTEABLE,0),2)       AS Volumen_Total_Litros,
    ROUND(ch.L_POR_UD_NO_TOTEABLE, 4)                                                         AS Volumetria_Litros_Por_Unidad,
    NULL AS Binfullness
  FROM `your-project.analytics.CHECKIN_HORA` ch
  LEFT JOIN SKU_CHK sk ON sk.FECHA = ch.FECHA AND sk.HORA = ch.HORA
  UNION ALL
  -- DCI_TOT
  SELECT
    FORMAT_DATE('%Y-%m-%d', d.FECHA) AS FECHA, d.HORA, 'DCI_TOT' AS AREA,
    CAST(ROUND(COALESCE(sk.N_SKUS,0) * COALESCE(d.PCT_TOTEABLE,0) / 100.0) AS INT64)    AS SKUs_Distintos,
    CAST(d.UDS_TOTEABLE AS INT64)                                                          AS Cantidad_Total_Unidades,
    ROUND(CAST(d.UDS_TOTEABLE AS FLOAT64) * COALESCE(d.L_POR_UD_TOTEABLE,0),2)            AS Volumen_Total_Litros,
    ROUND(d.L_POR_UD_TOTEABLE, 4)                                                          AS Volumetria_Litros_Por_Unidad,
    NULL AS Binfullness
  FROM `your-project.analytics.DCI_HORA` d
  LEFT JOIN SKU_DCI sk ON sk.FECHA = d.FECHA AND sk.HORA = d.HORA
  UNION ALL
  -- DCI_NOT
  SELECT
    FORMAT_DATE('%Y-%m-%d', d.FECHA) AS FECHA, d.HORA, 'DCI_NOT' AS AREA,
    CAST(ROUND(COALESCE(sk.N_SKUS,0) * (1.0 - COALESCE(d.PCT_TOTEABLE,0)/100.0)) AS INT64) AS SKUs_Distintos,
    CAST(d.UDS_NO_TOTEABLE AS INT64)                                                          AS Cantidad_Total_Unidades,
    ROUND(CAST(d.UDS_NO_TOTEABLE AS FLOAT64) * COALESCE(d.L_POR_UD_NO_TOTEABLE,0),2)        AS Volumen_Total_Litros,
    ROUND(d.L_POR_UD_NO_TOTEABLE, 4)                                                          AS Volumetria_Litros_Por_Unidad,
    NULL AS Binfullness
  FROM `your-project.analytics.DCI_HORA` d
  LEFT JOIN SKU_DCI sk ON sk.FECHA = d.FECHA AND sk.HORA = d.HORA
)
SELECT FECHA, HORA, AREA, SKUs_Distintos, Cantidad_Total_Unidades,
       Volumen_Total_Litros, Volumetria_Litros_Por_Unidad, Binfullness
FROM base
ORDER BY FECHA DESC, HORA DESC, AREA;
