-- Caso 5: Sistema de Venta de Minerales y Gemas de Coleccion
-- MySQL 8.4 - Procedimientos R1, R4, R9, R10, R11 y R12
USE caso5_colecciones;

DROP PROCEDURE IF EXISTS sp_r1_colecciones_mayor_monto;
DROP PROCEDURE IF EXISTS sp_r4_colecciones_piezas_clientes;
DROP PROCEDURE IF EXISTS sp_r9_ventas_sobre_promedio_coleccion;
DROP PROCEDURE IF EXISTS sp_r10_piezas_sobre_promedio_tipo;
DROP PROCEDURE IF EXISTS sp_r11_clientes_sobre_promedios;
DROP PROCEDURE IF EXISTS sp_r12_colecciones_promedio_superior;

DELIMITER $$

CREATE PROCEDURE sp_r1_colecciones_mayor_monto(
    IN p_fecha_inicio DATE,
    IN p_fecha_termino DATE
)
BEGIN
    IF p_fecha_inicio IS NULL OR p_fecha_termino IS NULL OR p_fecha_inicio > p_fecha_termino THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'R1: rango de fechas invalido';
    END IF;

    SELECT c.id_coleccion,
           c.nombre AS coleccion,
           COUNT(DISTINCT v.id_venta) AS cantidad_ventas,
           COUNT(dv.nro_detalle) AS detalles_vendidos,
           ROUND(SUM(dv.precio_venta), 2) AS monto_ventas
    FROM coleccion c
    JOIN pieza p ON p.id_coleccion = c.id_coleccion
    JOIN detalle_venta dv ON dv.id_pieza = p.id_pieza
    JOIN venta v ON v.id_venta = dv.id_venta
    WHERE v.fecha BETWEEN p_fecha_inicio AND p_fecha_termino
    GROUP BY c.id_coleccion, c.nombre
    ORDER BY monto_ventas DESC, c.id_coleccion;
END$$

CREATE PROCEDURE sp_r4_colecciones_piezas_clientes(
    IN p_fecha_inicio DATE,
    IN p_fecha_termino DATE
)
BEGIN
    IF p_fecha_inicio IS NULL OR p_fecha_termino IS NULL OR p_fecha_inicio > p_fecha_termino THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'R4: rango de fechas invalido';
    END IF;

    SELECT c.id_coleccion,
           c.nombre AS coleccion,
           COUNT(DISTINCT p.id_pieza) AS piezas_distintas_vendidas,
           COUNT(dv.nro_detalle) AS unidades_en_detalle,
           COUNT(DISTINCT v.id_cliente) AS clientes_distintos,
           ROUND(SUM(dv.precio_venta), 2) AS monto_comercializado
    FROM coleccion c
    JOIN pieza p ON p.id_coleccion = c.id_coleccion
    JOIN detalle_venta dv ON dv.id_pieza = p.id_pieza
    JOIN venta v ON v.id_venta = dv.id_venta
    JOIN cliente cl ON cl.id_cliente = v.id_cliente
    WHERE v.fecha BETWEEN p_fecha_inicio AND p_fecha_termino
    GROUP BY c.id_coleccion, c.nombre
    ORDER BY piezas_distintas_vendidas DESC, clientes_distintos DESC, c.id_coleccion;
END$$

CREATE PROCEDURE sp_r9_ventas_sobre_promedio_coleccion(
    IN p_id_coleccion VARCHAR(10),
    IN p_fecha_inicio DATE,
    IN p_fecha_termino DATE
)
BEGIN
    IF p_id_coleccion IS NULL OR p_fecha_inicio IS NULL OR p_fecha_termino IS NULL
       OR p_fecha_inicio > p_fecha_termino THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'R9: parametros invalidos';
    END IF;

    SELECT DISTINCT v.id_venta,
           v.fecha,
           v.id_cliente,
           v.monto_total,
           ROUND((
               SELECT AVG(v2.monto_total)
               FROM venta v2
               WHERE v2.fecha BETWEEN p_fecha_inicio AND p_fecha_termino
                 AND EXISTS (
                     SELECT 1
                     FROM detalle_venta dv2
                     JOIN pieza p2 ON p2.id_pieza = dv2.id_pieza
                     WHERE dv2.id_venta = v2.id_venta
                       AND p2.id_coleccion = p_id_coleccion
                 )
           ), 2) AS promedio_ventas_coleccion
    FROM venta v
    WHERE v.fecha BETWEEN p_fecha_inicio AND p_fecha_termino
      AND EXISTS (
          SELECT 1
          FROM detalle_venta dv
          JOIN pieza p ON p.id_pieza = dv.id_pieza
          WHERE dv.id_venta = v.id_venta
            AND p.id_coleccion = p_id_coleccion
      )
      AND v.monto_total > (
          SELECT AVG(v2.monto_total)
          FROM venta v2
          WHERE v2.fecha BETWEEN p_fecha_inicio AND p_fecha_termino
            AND EXISTS (
                SELECT 1
                FROM detalle_venta dv2
                JOIN pieza p2 ON p2.id_pieza = dv2.id_pieza
                WHERE dv2.id_venta = v2.id_venta
                  AND p2.id_coleccion = p_id_coleccion
            )
      )
    ORDER BY v.monto_total DESC, v.id_venta;
END$$

CREATE PROCEDURE sp_r10_piezas_sobre_promedio_tipo(
    IN p_tipo_pieza VARCHAR(20)
)
BEGIN
    SET p_tipo_pieza = UPPER(TRIM(p_tipo_pieza));
    IF p_tipo_pieza NOT IN ('MINERAL','FOSIL','GEMA','SIN_CLASIFICAR') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'R10: tipo valido: MINERAL, FOSIL, GEMA o SIN_CLASIFICAR';
    END IF;

    SELECT x.id_pieza,
           x.nombre_comercial,
           x.tipo_pieza,
           x.cantidad_ventas,
           x.precio_promedio_pieza,
           ROUND((
               SELECT AVG(y.precio_promedio_pieza)
               FROM (
                   SELECT p2.id_pieza,
                          CASE
                              WHEN m2.id_pieza IS NOT NULL THEN 'MINERAL'
                              WHEN f2.id_pieza IS NOT NULL THEN 'FOSIL'
                              WHEN g2.id_pieza IS NOT NULL THEN 'GEMA'
                              ELSE 'SIN_CLASIFICAR'
                          END AS tipo_pieza,
                          AVG(dv2.precio_venta) AS precio_promedio_pieza
                   FROM pieza p2
                   LEFT JOIN mineral m2 ON m2.id_pieza = p2.id_pieza
                   LEFT JOIN fosil f2 ON f2.id_pieza = p2.id_pieza
                   LEFT JOIN gema g2 ON g2.id_pieza = p2.id_pieza
                   JOIN detalle_venta dv2 ON dv2.id_pieza = p2.id_pieza
                   JOIN venta v2 ON v2.id_venta = dv2.id_venta
                   GROUP BY p2.id_pieza,
                       CASE
                           WHEN m2.id_pieza IS NOT NULL THEN 'MINERAL'
                           WHEN f2.id_pieza IS NOT NULL THEN 'FOSIL'
                           WHEN g2.id_pieza IS NOT NULL THEN 'GEMA'
                           ELSE 'SIN_CLASIFICAR'
                       END
               ) y
               WHERE y.tipo_pieza = x.tipo_pieza
           ), 2) AS promedio_del_tipo
    FROM (
        SELECT p.id_pieza,
               p.nombre_comercial,
               CASE
                   WHEN m.id_pieza IS NOT NULL THEN 'MINERAL'
                   WHEN f.id_pieza IS NOT NULL THEN 'FOSIL'
                   WHEN g.id_pieza IS NOT NULL THEN 'GEMA'
                   ELSE 'SIN_CLASIFICAR'
               END AS tipo_pieza,
               COUNT(dv.id_venta) AS cantidad_ventas,
               ROUND(AVG(dv.precio_venta), 2) AS precio_promedio_pieza
        FROM pieza p
        LEFT JOIN mineral m ON m.id_pieza = p.id_pieza
        LEFT JOIN fosil f ON f.id_pieza = p.id_pieza
        LEFT JOIN gema g ON g.id_pieza = p.id_pieza
        JOIN detalle_venta dv ON dv.id_pieza = p.id_pieza
        JOIN venta v ON v.id_venta = dv.id_venta
        GROUP BY p.id_pieza, p.nombre_comercial,
            CASE
                WHEN m.id_pieza IS NOT NULL THEN 'MINERAL'
                WHEN f.id_pieza IS NOT NULL THEN 'FOSIL'
                WHEN g.id_pieza IS NOT NULL THEN 'GEMA'
                ELSE 'SIN_CLASIFICAR'
            END
    ) x
    WHERE x.tipo_pieza = p_tipo_pieza
      AND x.precio_promedio_pieza > (
          SELECT AVG(y.precio_promedio_pieza)
          FROM (
              SELECT p2.id_pieza,
                     CASE
                         WHEN m2.id_pieza IS NOT NULL THEN 'MINERAL'
                         WHEN f2.id_pieza IS NOT NULL THEN 'FOSIL'
                         WHEN g2.id_pieza IS NOT NULL THEN 'GEMA'
                         ELSE 'SIN_CLASIFICAR'
                     END AS tipo_pieza,
                     AVG(dv2.precio_venta) AS precio_promedio_pieza
              FROM pieza p2
              LEFT JOIN mineral m2 ON m2.id_pieza = p2.id_pieza
              LEFT JOIN fosil f2 ON f2.id_pieza = p2.id_pieza
              LEFT JOIN gema g2 ON g2.id_pieza = p2.id_pieza
              JOIN detalle_venta dv2 ON dv2.id_pieza = p2.id_pieza
              JOIN venta v2 ON v2.id_venta = dv2.id_venta
              GROUP BY p2.id_pieza,
                  CASE
                      WHEN m2.id_pieza IS NOT NULL THEN 'MINERAL'
                      WHEN f2.id_pieza IS NOT NULL THEN 'FOSIL'
                      WHEN g2.id_pieza IS NOT NULL THEN 'GEMA'
                      ELSE 'SIN_CLASIFICAR'
                  END
          ) y
          WHERE y.tipo_pieza = x.tipo_pieza
      )
    ORDER BY x.precio_promedio_pieza DESC, x.id_pieza;
END$$

CREATE PROCEDURE sp_r11_clientes_sobre_promedios(
    IN p_fecha_inicio DATE,
    IN p_fecha_termino DATE
)
BEGIN
    IF p_fecha_inicio IS NULL OR p_fecha_termino IS NULL OR p_fecha_inicio > p_fecha_termino THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'R11: rango de fechas invalido';
    END IF;

    SELECT r.id_cliente,
           r.cliente,
           r.cantidad_compras,
           r.monto_pagado,
           r.promedio_evaluacion,
           ROUND((SELECT AVG(z.cantidad_compras) FROM (
               SELECT COUNT(*) AS cantidad_compras
               FROM venta
               WHERE fecha BETWEEN p_fecha_inicio AND p_fecha_termino
               GROUP BY id_cliente
           ) z), 2) AS promedio_compras_clientes,
           ROUND((SELECT AVG(e.calificacion)
                  FROM evaluacion e
                  JOIN venta v ON v.id_venta = e.id_venta
                  WHERE v.fecha BETWEEN p_fecha_inicio AND p_fecha_termino), 2) AS promedio_evaluacion_general
    FROM (
        SELECT sv.id_cliente,
               sv.cliente,
               COUNT(*) AS cantidad_compras,
               ROUND(SUM(sv.monto_detalles), 2) AS monto_pagado,
               ROUND(AVG(sv.promedio_evaluacion_venta), 2) AS promedio_evaluacion
        FROM (
            SELECT v.id_venta,
                   c.id_cliente,
                   c.nombre_razon_social AS cliente,
                   SUM(dv.precio_venta) AS monto_detalles,
                   ea.promedio_evaluacion_venta
            FROM cliente c
            JOIN venta v ON v.id_cliente = c.id_cliente
            JOIN detalle_venta dv ON dv.id_venta = v.id_venta
            JOIN (
                SELECT id_venta, AVG(calificacion) AS promedio_evaluacion_venta
                FROM evaluacion
                GROUP BY id_venta
            ) ea ON ea.id_venta = v.id_venta
            WHERE v.fecha BETWEEN p_fecha_inicio AND p_fecha_termino
            GROUP BY v.id_venta, c.id_cliente, c.nombre_razon_social,
                     ea.promedio_evaluacion_venta
        ) sv
        GROUP BY sv.id_cliente, sv.cliente
    ) r
    WHERE r.cantidad_compras > (
              SELECT AVG(z.cantidad_compras)
              FROM (
                  SELECT COUNT(*) AS cantidad_compras
                  FROM venta
                  WHERE fecha BETWEEN p_fecha_inicio AND p_fecha_termino
                  GROUP BY id_cliente
              ) z
          )
      AND r.promedio_evaluacion > (
              SELECT AVG(e.calificacion)
              FROM evaluacion e
              JOIN venta v ON v.id_venta = e.id_venta
              WHERE v.fecha BETWEEN p_fecha_inicio AND p_fecha_termino
          )
    ORDER BY r.cantidad_compras DESC, r.promedio_evaluacion DESC, r.id_cliente;
END$$

CREATE PROCEDURE sp_r12_colecciones_promedio_superior(
    IN p_fecha_inicio DATE,
    IN p_fecha_termino DATE
)
BEGIN
    IF p_fecha_inicio IS NULL OR p_fecha_termino IS NULL OR p_fecha_inicio > p_fecha_termino THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'R12: rango de fechas invalido';
    END IF;

    SELECT x.id_coleccion,
           x.coleccion,
           x.piezas_distintas,
           x.detalles_vendidos,
           x.monto_total,
           x.monto_promedio_por_pieza,
           ROUND((SELECT AVG(y.monto_promedio_por_pieza)
                  FROM (
                      SELECT p2.id_coleccion,
                             SUM(dv2.precio_venta) / COUNT(DISTINCT p2.id_pieza) AS monto_promedio_por_pieza
                      FROM pieza p2
                      JOIN detalle_venta dv2 ON dv2.id_pieza = p2.id_pieza
                      JOIN venta v2 ON v2.id_venta = dv2.id_venta
                      WHERE v2.fecha BETWEEN p_fecha_inicio AND p_fecha_termino
                      GROUP BY p2.id_coleccion
                  ) y), 2) AS promedio_general_colecciones
    FROM (
        SELECT c.id_coleccion,
               c.nombre AS coleccion,
               COUNT(DISTINCT p.id_pieza) AS piezas_distintas,
               COUNT(dv.nro_detalle) AS detalles_vendidos,
               ROUND(SUM(dv.precio_venta), 2) AS monto_total,
               ROUND(SUM(dv.precio_venta) / COUNT(DISTINCT p.id_pieza), 2) AS monto_promedio_por_pieza
        FROM coleccion c
        JOIN pieza p ON p.id_coleccion = c.id_coleccion
        JOIN detalle_venta dv ON dv.id_pieza = p.id_pieza
        JOIN venta v ON v.id_venta = dv.id_venta
        WHERE v.fecha BETWEEN p_fecha_inicio AND p_fecha_termino
        GROUP BY c.id_coleccion, c.nombre
    ) x
    WHERE x.monto_promedio_por_pieza > (
        SELECT AVG(y.monto_promedio_por_pieza)
        FROM (
            SELECT p2.id_coleccion,
                   SUM(dv2.precio_venta) / COUNT(DISTINCT p2.id_pieza) AS monto_promedio_por_pieza
            FROM pieza p2
            JOIN detalle_venta dv2 ON dv2.id_pieza = p2.id_pieza
            JOIN venta v2 ON v2.id_venta = dv2.id_venta
            WHERE v2.fecha BETWEEN p_fecha_inicio AND p_fecha_termino
            GROUP BY p2.id_coleccion
        ) y
    )
    ORDER BY x.monto_promedio_por_pieza DESC, x.id_coleccion;
END$$

DELIMITER ;
