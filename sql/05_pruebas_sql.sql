-- Pruebas R1-R12 para MySQL 8.4
USE caso5_colecciones;

-- Verificacion de objetos
SHOW FULL TABLES WHERE Table_type = 'VIEW';
SHOW PROCEDURE STATUS WHERE Db = DATABASE();

-- R1 procedure: colecciones con mayor monto de ventas por periodo
CALL sp_r1_colecciones_mayor_monto('2024-01-01', '2025-12-31');

-- R2 view: distribucion de piezas comercializadas por tipo y coleccion
SELECT *
FROM vw_r2_distribucion_piezas_comercializadas
ORDER BY coleccion, tipo_pieza;

-- R3 view: relacion monto de venta / evaluacion
SELECT *
FROM vw_r3_monto_venta_evaluacion
ORDER BY monto_total DESC, id_venta;

-- R4 procedure: piezas vendidas y clientes distintos por coleccion
CALL sp_r4_colecciones_piezas_clientes('2024-01-01', '2025-12-31');

-- R5 view: proporcion comercializada por coleccion
SELECT *
FROM vw_r5_proporcion_piezas_vendidas
ORDER BY porcentaje_comercializacion DESC, id_coleccion;

-- R6 view: ingreso acumulado por pieza, coleccion y tipo
SELECT *
FROM vw_r6_ingreso_pieza_coleccion_tipo
ORDER BY ingreso_acumulado DESC, id_pieza;

-- R7 view: diversidad de exposiciones y ventas posteriores
SELECT *
FROM vw_r7_diversidad_exposiciones
ORDER BY piezas_exhibidas DESC, piezas_comercializadas_posteriormente DESC;

-- R8 view: clientes con mas compras y monto acumulado
SELECT *
FROM vw_r8_clientes_compras_monto
ORDER BY cantidad_compras DESC, monto_total_pagado DESC;

-- R9 procedure: ventas sobre el promedio de una coleccion
CALL sp_r9_ventas_sobre_promedio_coleccion('COL001', '2022-01-01', '2025-12-31');

-- R10 procedure: piezas sobre el promedio de su tipo
CALL sp_r10_piezas_sobre_promedio_tipo('MINERAL');
CALL sp_r10_piezas_sobre_promedio_tipo('FOSIL');
CALL sp_r10_piezas_sobre_promedio_tipo('GEMA');

-- R11 procedure: clientes sobre ambos promedios
CALL sp_r11_clientes_sobre_promedios('2022-01-01', '2025-12-31');

-- R12 procedure: colecciones con promedio por pieza superior al general
CALL sp_r12_colecciones_promedio_superior('2022-01-01', '2025-12-31');

-- Controles auxiliares: deben devolver 0 filas/errores
SELECT v.id_venta, v.monto_total, SUM(dv.precio_venta) AS suma_detalles
FROM venta v
JOIN detalle_venta dv ON dv.id_venta = v.id_venta
GROUP BY v.id_venta, v.monto_total
HAVING v.monto_total <> SUM(dv.precio_venta);

SELECT p.id_pieza
FROM pieza p
LEFT JOIN mineral m ON m.id_pieza = p.id_pieza
LEFT JOIN fosil f ON f.id_pieza = p.id_pieza
LEFT JOIN gema g ON g.id_pieza = p.id_pieza
WHERE (m.id_pieza IS NOT NULL) + (f.id_pieza IS NOT NULL) + (g.id_pieza IS NOT NULL) > 1;
