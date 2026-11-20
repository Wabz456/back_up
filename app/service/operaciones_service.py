"""Reglas de negocio del Video 7."""
from __future__ import annotations
from datetime import date
from decimal import Decimal, InvalidOperation
from typing import Any
from sqlalchemy.engine import Engine
from sqlalchemy.exc import IntegrityError
from db.operaciones_dao import insertar_venta, insertar_detalles

class ValidacionError(ValueError):
    pass


def texto_obligatorio(valor: Any, nombre: str, maximo: int) -> str:
    limpio = str(valor or "").strip()
    if not limpio:
        raise ValidacionError(f"{nombre} es obligatorio.")
    if len(limpio) > maximo:
        raise ValidacionError(f"{nombre} admite como máximo {maximo} caracteres.")
    return limpio


def decimal_no_negativo(valor: Any, nombre: str) -> Decimal:
    try:
        numero = Decimal(str(valor)).quantize(Decimal("0.01"))
    except (InvalidOperation, ValueError):
        raise ValidacionError(f"{nombre} debe ser numérico.") from None
    if numero < 0:
        raise ValidacionError(f"{nombre} no puede ser negativo.")
    return numero


def registrar_venta(engine: Engine, id_venta: str, id_cliente: str,
                    id_trabajador: str, fecha: date,
                    detalles: list[dict[str, Any]]) -> Decimal:
    id_venta = texto_obligatorio(id_venta, "ID de venta", 12)
    id_cliente = texto_obligatorio(id_cliente, "Cliente", 10)
    id_trabajador = texto_obligatorio(id_trabajador, "Trabajador", 10)
    if not detalles:
        raise ValidacionError("La venta debe contener al menos una pieza.")
    ids = [texto_obligatorio(d.get("id_pieza"), "Pieza", 10) for d in detalles]
    if len(ids) != len(set(ids)):
        raise ValidacionError("Una pieza no puede repetirse en la misma venta.")
    normalizados = []
    for detalle, id_pieza in zip(detalles, ids):
        normalizados.append({
            "id_pieza": id_pieza,
            "precio_venta": decimal_no_negativo(detalle.get("precio_venta"), "Precio de venta"),
            "condiciones": str(detalle.get("condiciones") or "").strip()[:250] or None,
        })
    total = sum((d["precio_venta"] for d in normalizados), Decimal("0.00"))
    # engine.begin confirma al terminar y revierte automáticamente ante excepción.
    with engine.begin() as cn:
        insertar_venta(cn, id_venta, id_cliente, id_trabajador, fecha, total)
        insertar_detalles(cn, id_venta, normalizados)
    return total


def mensaje_integridad(exc: IntegrityError, entidad: str) -> str:
    texto = str(exc.orig).lower()
    if "duplicate" in texto:
        return f"No se pudo guardar {entidad}: el identificador ya existe."
    if "foreign key" in texto:
        return (f"No se pudo completar la operación sobre {entidad}: existen referencias "
                "relacionadas o una clave asociada no existe. Desactive el registro si corresponde.")
    return f"No se pudo guardar {entidad} por una restricción de integridad."
