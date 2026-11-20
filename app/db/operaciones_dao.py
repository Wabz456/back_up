"""Capa de datos del Video 7 para colecciones, piezas, ventas y evaluaciones."""
from __future__ import annotations

from datetime import date
from decimal import Decimal
from typing import Any, Iterable

from sqlalchemy import text
from sqlalchemy.engine import Connection, Engine


def _rows(result) -> list[dict[str, Any]]:
    return [dict(row) for row in result.mappings().all()]


# ---------- Catalogos ----------
def listar_clientes(engine: Engine) -> list[dict[str, Any]]:
    sql = text("""SELECT id_cliente, nombre_razon_social
                  FROM cliente ORDER BY nombre_razon_social""")
    with engine.connect() as cn:
        return _rows(cn.execute(sql))


def listar_trabajadores(engine: Engine) -> list[dict[str, Any]]:
    sql = text("""SELECT id_trabajador, nombre
                  FROM trabajador ORDER BY nombre""")
    with engine.connect() as cn:
        return _rows(cn.execute(sql))


def listar_piezas_activas(engine: Engine) -> list[dict[str, Any]]:
    sql = text("""SELECT p.id_pieza, p.nombre_comercial, p.valor_estimado,
                         c.nombre AS coleccion
                  FROM pieza p
                  JOIN coleccion c ON c.id_coleccion = p.id_coleccion
                  WHERE p.activa = TRUE AND c.activa = TRUE
                  ORDER BY c.nombre, p.nombre_comercial""")
    with engine.connect() as cn:
        return _rows(cn.execute(sql))


# ---------- Venta transaccional ----------
def insertar_venta(
    cn: Connection,
    id_venta: str,
    id_cliente: str,
    id_trabajador: str,
    fecha: date,
    monto_total: Decimal,
) -> None:
    cn.execute(text("""INSERT INTO venta
        (id_venta, id_cliente, id_trabajador, fecha, monto_total)
        VALUES (:id_venta, :id_cliente, :id_trabajador, :fecha, :monto_total)"""), {
        "id_venta": id_venta, "id_cliente": id_cliente,
        "id_trabajador": id_trabajador, "fecha": fecha,
        "monto_total": monto_total,
    })


def insertar_detalles(cn: Connection, id_venta: str, detalles: Iterable[dict[str, Any]]) -> None:
    sql = text("""INSERT INTO detalle_venta
        (id_venta, nro_detalle, id_pieza, precio_venta, condiciones)
        VALUES (:id_venta, :nro_detalle, :id_pieza, :precio_venta, :condiciones)""")
    for numero, detalle in enumerate(detalles, start=1):
        cn.execute(sql, {
            "id_venta": id_venta, "nro_detalle": numero,
            "id_pieza": detalle["id_pieza"],
            "precio_venta": detalle["precio_venta"],
            "condiciones": detalle.get("condiciones") or None,
        })


def obtener_venta(engine: Engine, id_venta: str) -> dict[str, Any] | None:
    sql = text("""SELECT v.id_venta, v.fecha, v.monto_total,
                         c.nombre_razon_social AS cliente, t.nombre AS trabajador
                  FROM venta v JOIN cliente c ON c.id_cliente=v.id_cliente
                  JOIN trabajador t ON t.id_trabajador=v.id_trabajador
                  WHERE v.id_venta=:id_venta""")
    with engine.connect() as cn:
        row = cn.execute(sql, {"id_venta": id_venta}).mappings().first()
        return dict(row) if row else None


# ---------- Coleccion CRUD ----------
def buscar_colecciones(engine: Engine, termino: str = "") -> list[dict[str, Any]]:
    sql = text("""SELECT id_coleccion, nombre, tematica, fecha_creacion,
                         responsable, estado_conservacion, activa
                  FROM coleccion
                  WHERE :termino = '' OR id_coleccion LIKE :patron
                     OR nombre LIKE :patron OR tematica LIKE :patron
                  ORDER BY nombre""")
    with engine.connect() as cn:
        return _rows(cn.execute(sql, {"termino": termino, "patron": f"%{termino}%"}))


def crear_coleccion(engine: Engine, datos: dict[str, Any]) -> None:
    sql = text("""INSERT INTO coleccion
        (id_coleccion,nombre,tematica,fecha_creacion,responsable,estado_conservacion,activa)
        VALUES (:id_coleccion,:nombre,:tematica,:fecha_creacion,:responsable,
                :estado_conservacion,:activa)""")
    with engine.begin() as cn:
        cn.execute(sql, datos)


def actualizar_coleccion(engine: Engine, id_coleccion: str, datos: dict[str, Any]) -> int:
    sql = text("""UPDATE coleccion SET nombre=:nombre, tematica=:tematica,
        fecha_creacion=:fecha_creacion, responsable=:responsable,
        estado_conservacion=:estado_conservacion, activa=:activa
        WHERE id_coleccion=:id_coleccion""")
    with engine.begin() as cn:
        return cn.execute(sql, {**datos, "id_coleccion": id_coleccion}).rowcount


def eliminar_coleccion(engine: Engine, id_coleccion: str) -> int:
    with engine.begin() as cn:
        return cn.execute(text("DELETE FROM coleccion WHERE id_coleccion=:id"), {"id": id_coleccion}).rowcount


# ---------- Pieza CRUD ----------
def buscar_piezas(engine: Engine, termino: str = "") -> list[dict[str, Any]]:
    sql = text("""SELECT p.id_pieza,p.id_coleccion,c.nombre AS coleccion,
        p.nombre_comercial,p.procedencia_pais,p.procedencia_region,
        p.procedencia_localidad,p.fecha_adquisicion,p.valor_estimado,
        p.estado_conservacion,p.nivel_rareza,p.activa
        FROM pieza p JOIN coleccion c ON c.id_coleccion=p.id_coleccion
        WHERE :termino='' OR p.id_pieza LIKE :patron
           OR p.nombre_comercial LIKE :patron OR c.nombre LIKE :patron
        ORDER BY p.nombre_comercial""")
    with engine.connect() as cn:
        return _rows(cn.execute(sql, {"termino": termino, "patron": f"%{termino}%"}))


def crear_pieza(engine: Engine, datos: dict[str, Any]) -> None:
    sql = text("""INSERT INTO pieza
        (id_pieza,id_coleccion,nombre_comercial,procedencia_pais,
         procedencia_region,procedencia_localidad,fecha_adquisicion,
         valor_estimado,estado_conservacion,nivel_rareza,activa)
        VALUES (:id_pieza,:id_coleccion,:nombre_comercial,:procedencia_pais,
         :procedencia_region,:procedencia_localidad,:fecha_adquisicion,
         :valor_estimado,:estado_conservacion,:nivel_rareza,:activa)""")
    with engine.begin() as cn:
        cn.execute(sql, datos)


def actualizar_pieza(engine: Engine, id_pieza: str, datos: dict[str, Any]) -> int:
    sql = text("""UPDATE pieza SET id_coleccion=:id_coleccion,
        nombre_comercial=:nombre_comercial, procedencia_pais=:procedencia_pais,
        procedencia_region=:procedencia_region, procedencia_localidad=:procedencia_localidad,
        fecha_adquisicion=:fecha_adquisicion, valor_estimado=:valor_estimado,
        estado_conservacion=:estado_conservacion, nivel_rareza=:nivel_rareza,
        activa=:activa WHERE id_pieza=:id_pieza""")
    with engine.begin() as cn:
        return cn.execute(sql, {**datos, "id_pieza": id_pieza}).rowcount


def eliminar_pieza(engine: Engine, id_pieza: str) -> int:
    with engine.begin() as cn:
        return cn.execute(text("DELETE FROM pieza WHERE id_pieza=:id"), {"id": id_pieza}).rowcount


# ---------- Evaluacion ----------
def crear_evaluacion(engine: Engine, datos: dict[str, Any]) -> None:
    sql = text("""INSERT INTO evaluacion
        (id_venta,nro_evaluacion,fecha,calificacion,comentario)
        VALUES (:id_venta,:nro_evaluacion,:fecha,:calificacion,:comentario)""")
    with engine.begin() as cn:
        cn.execute(sql, datos)
