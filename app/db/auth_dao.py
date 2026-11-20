"""Acceso a datos de autenticación sobre cuenta_usuario, rol y usuario_rol."""
from __future__ import annotations
from typing import Any
from sqlalchemy import text
from sqlalchemy.engine import Connection, Engine


def buscar_cuenta_por_usuario(engine: Engine, usuario: str) -> dict[str, Any] | None:
    sql = text("""SELECT cu.id_cuenta, cu.id_trabajador, cu.usuario,
                         cu.password_hash, cu.activa, t.nombre AS nombre_trabajador
                  FROM cuenta_usuario cu
                  JOIN trabajador t ON t.id_trabajador = cu.id_trabajador
                  WHERE cu.usuario = :usuario""")
    with engine.connect() as cn:
        fila = cn.execute(sql, {"usuario": usuario}).mappings().first()
        return dict(fila) if fila else None


def listar_roles_de_cuenta(engine: Engine, id_cuenta: str) -> frozenset[str]:
    sql = text("""SELECT r.nombre_rol
                  FROM usuario_rol ur JOIN rol r ON r.id_rol = ur.id_rol
                  WHERE ur.id_cuenta = :id_cuenta""")
    with engine.connect() as cn:
        return frozenset(cn.execute(sql, {"id_cuenta": id_cuenta}).scalars().all())


def buscar_rol_por_nombre(cn: Connection, nombre_rol: str) -> str | None:
    return cn.execute(
        text("SELECT id_rol FROM rol WHERE nombre_rol = :nombre_rol"),
        {"nombre_rol": nombre_rol},
    ).scalar_one_or_none()


def actualizar_hash(cn: Connection, id_cuenta: str, password_hash: str) -> int:
    return cn.execute(
        text("""UPDATE cuenta_usuario SET password_hash = :password_hash
                WHERE id_cuenta = :id_cuenta"""),
        {"password_hash": password_hash, "id_cuenta": id_cuenta},
    ).rowcount


def asignar_rol(cn: Connection, id_cuenta: str, id_rol: str) -> None:
    cn.execute(text("""INSERT INTO usuario_rol (id_cuenta, id_rol)
                       VALUES (:id_cuenta, :id_rol)
                       ON DUPLICATE KEY UPDATE id_rol = VALUES(id_rol)"""),
               {"id_cuenta": id_cuenta, "id_rol": id_rol})
