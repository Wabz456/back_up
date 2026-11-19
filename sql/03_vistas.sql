-- Caso 5: Sistema de Venta de Minerales y Gemas de Coleccion
-- MySQL 8.4 - Vistas R2, R3, R5, R6, R7 y R8
USE caso5_colecciones;

DROP VIEW IF EXISTS vw_r2_distribucion_piezas_comercializadas;
CREATE VIEW vw_r2_distribucion_piezas_comercializadas AS
SELECT
    c.id_coleccion,
    c.nombre AS coleccion,
    CASE
        WHEN m.id_pieza IS NOT NULL THEN 'MINERAL'
        WHEN f.id_pieza IS NOT NULL THEN 'FOSIL'
        WHEN g.id_pieza IS NOT NULL THEN 'GEMA'
        ELSE 'SIN_CLASIFICAR'
    END AS tipo_pieza,
    COUNT(DISTINCT p.id_pieza) AS piezas_comercializadas,
    COUNT(DISTINCT dv.id_venta) AS ventas_asociadas,
    ROUND(SUM(dv.precio_venta), 2) AS monto_comercializado
FROM coleccion c
JOIN pieza p ON p.id_coleccion = c.id_coleccion
LEFT JOIN mineral m ON m.id_pieza = p.id_pieza
LEFT JOIN fosil f ON f.id_pieza = p.id_pieza
LEFT JOIN gema g ON g.id_pieza = p.id_pieza
JOIN detalle_venta dv ON dv.id_pieza = p.id_pieza
JOIN venta v ON v.id_venta = dv.id_venta
GROUP BY c.id_coleccion, c.nombre,
    CASE
        WHEN m.id_pieza IS NOT NULL THEN 'MINERAL'
        WHEN f.id_pieza IS NOT NULL THEN 'FOSIL'
        WHEN g.id_pieza IS NOT NULL THEN 'GEMA'
        ELSE 'SIN_CLASIFICAR'
    END;

DROP VIEW IF EXISTS vw_r3_monto_venta_evaluacion;
CREATE VIEW vw_r3_monto_venta_evaluacion AS
SELECT
    v.id_venta,
    v.fecha AS fecha_venta,
    c.id_cliente,
    c.nombre_razon_social AS cliente,
    v.monto_total,
    COALESCE(d.cantidad_piezas, 0) AS cantidad_piezas,
    e.cantidad_evaluaciones,
    e.promedio_evaluacion
FROM venta v
JOIN cliente c ON c.id_cliente = v.id_cliente
JOIN (
    SELECT id_venta, COUNT(*) AS cantidad_piezas
    FROM detalle_venta
    GROUP BY id_venta
) d ON d.id_venta = v.id_venta
JOIN (
    SELECT id_venta,
           COUNT(*) AS cantidad_evaluaciones,
           ROUND(AVG(calificacion), 2) AS promedio_evaluacion
    FROM evaluacion
    GROUP BY id_venta
) e ON e.id_venta = v.id_venta;

DROP VIEW IF EXISTS vw_r5_proporcion_piezas_vendidas;
CREATE VIEW vw_r5_proporcion_piezas_vendidas AS
SELECT
    c.id_coleccion,
    c.nombre AS coleccion,
    COUNT(DISTINCT p.id_pieza) AS total_piezas_registradas,
    COUNT(DISTINCT CASE WHEN dv.id_pieza IS NOT NULL THEN p.id_pieza END) AS piezas_vendidas,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN dv.id_pieza IS NOT NULL THEN p.id_pieza END)
        / NULLIF(COUNT(DISTINCT p.id_pieza), 0),
        2
    ) AS porcentaje_comercializacion
FROM coleccion c
LEFT JOIN pieza p ON p.id_coleccion = c.id_coleccion
LEFT JOIN detalle_venta dv ON dv.id_pieza = p.id_pieza
LEFT JOIN venta v ON v.id_venta = dv.id_venta
GROUP BY c.id_coleccion, c.nombre;

DROP VIEW IF EXISTS vw_r6_ingreso_pieza_coleccion_tipo;
CREATE VIEW vw_r6_ingreso_pieza_coleccion_tipo AS
SELECT
    c.id_coleccion,
    c.nombre AS coleccion,
    p.id_pieza,
    p.nombre_comercial AS pieza,
    CASE
        WHEN m.id_pieza IS NOT NULL THEN 'MINERAL'
        WHEN f.id_pieza IS NOT NULL THEN 'FOSIL'
        WHEN g.id_pieza IS NOT NULL THEN 'GEMA'
        ELSE 'SIN_CLASIFICAR'
    END AS tipo_pieza,
    COUNT(dv.id_venta) AS veces_comercializada,
    ROUND(SUM(dv.precio_venta), 2) AS ingreso_acumulado
FROM coleccion c
JOIN pieza p ON p.id_coleccion = c.id_coleccion
LEFT JOIN mineral m ON m.id_pieza = p.id_pieza
LEFT JOIN fosil f ON f.id_pieza = p.id_pieza
LEFT JOIN gema g ON g.id_pieza = p.id_pieza
JOIN detalle_venta dv ON dv.id_pieza = p.id_pieza
GROUP BY c.id_coleccion, c.nombre, p.id_pieza, p.nombre_comercial,
    CASE
        WHEN m.id_pieza IS NOT NULL THEN 'MINERAL'
        WHEN f.id_pieza IS NOT NULL THEN 'FOSIL'
        WHEN g.id_pieza IS NOT NULL THEN 'GEMA'
        ELSE 'SIN_CLASIFICAR'
    END;

DROP VIEW IF EXISTS vw_r7_diversidad_exposiciones;
CREATE VIEW vw_r7_diversidad_exposiciones AS
SELECT
    e.id_exposicion,
    e.nombre AS exposicion,
    e.fecha_inicio,
    e.fecha_termino,
    e.ubicacion,
    COUNT(DISTINCT pe.id_pieza) AS piezas_exhibidas,
    COUNT(DISTINCT CASE
        WHEN EXISTS (
            SELECT 1
            FROM detalle_venta dv
            JOIN venta v ON v.id_venta = dv.id_venta
            WHERE dv.id_pieza = pe.id_pieza
              AND v.fecha > e.fecha_termino
        ) THEN pe.id_pieza
    END) AS piezas_comercializadas_posteriormente,
    COUNT(DISTINCT CASE WHEN m.id_pieza IS NOT NULL THEN pe.id_pieza END) AS minerales_exhibidos,
    COUNT(DISTINCT CASE WHEN f.id_pieza IS NOT NULL THEN pe.id_pieza END) AS fosiles_exhibidos,
    COUNT(DISTINCT CASE WHEN g.id_pieza IS NOT NULL THEN pe.id_pieza END) AS gemas_exhibidas,
    COUNT(DISTINCT CASE
        WHEN m.id_pieza IS NULL AND f.id_pieza IS NULL AND g.id_pieza IS NULL
        THEN pe.id_pieza
    END) AS piezas_sin_clasificar
FROM exposicion e
JOIN participacion_exposicion pe ON pe.id_exposicion = e.id_exposicion
JOIN pieza p ON p.id_pieza = pe.id_pieza
LEFT JOIN mineral m ON m.id_pieza = p.id_pieza
LEFT JOIN fosil f ON f.id_pieza = p.id_pieza
LEFT JOIN gema g ON g.id_pieza = p.id_pieza
GROUP BY e.id_exposicion, e.nombre, e.fecha_inicio, e.fecha_termino, e.ubicacion;

DROP VIEW IF EXISTS vw_r8_clientes_compras_monto;
CREATE VIEW vw_r8_clientes_compras_monto AS
SELECT
    c.id_cliente,
    c.nombre_razon_social AS cliente,
    COUNT(DISTINCT v.id_venta) AS cantidad_compras,
    COUNT(dv.nro_detalle) AS piezas_compradas,
    ROUND(SUM(dv.precio_venta), 2) AS monto_total_pagado
FROM cliente c
JOIN venta v ON v.id_cliente = c.id_cliente
JOIN detalle_venta dv ON dv.id_venta = v.id_venta
GROUP BY c.id_cliente, c.nombre_razon_social
HAVING COUNT(DISTINCT v.id_venta) > 0;
