"""Autenticación bcrypt, sesión y autorización del PMV."""
from __future__ import annotations
from dataclasses import dataclass
import bcrypt
from sqlalchemy.engine import Engine
from db.auth_dao import buscar_cuenta_por_usuario, listar_roles_de_cuenta

ROL_ADMIN = "ADMINISTRADOR"
ROL_CONSULTA = "CONSULTA"
PERMISO_CONSULTAR = "CONSULTAR"
PERMISO_ESCRIBIR = "ESCRIBIR"

class AutenticacionError(ValueError): pass
class AutorizacionError(PermissionError): pass

@dataclass(frozen=True)
class SesionUsuario:
    id_cuenta: str
    id_trabajador: str
    usuario: str
    nombre_trabajador: str
    roles: frozenset[str]


def hash_password(password: str) -> str:
    if len(password) < 8:
        raise AutenticacionError("La contraseña debe tener al menos 8 caracteres.")
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verificar_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))
    except (ValueError, TypeError):
        return False


def autenticar(engine: Engine, usuario: str, password: str) -> SesionUsuario:
    usuario = usuario.strip()
    if not usuario or not password:
        raise AutenticacionError("Ingrese usuario y contraseña.")
    cuenta = buscar_cuenta_por_usuario(engine, usuario)
    mensaje = "Usuario o contraseña incorrectos."
    if not cuenta or not cuenta["activa"] or not cuenta.get("password_hash"):
        raise AutenticacionError(mensaje)
    if not verificar_password(password, cuenta["password_hash"]):
        raise AutenticacionError(mensaje)
    roles = listar_roles_de_cuenta(engine, cuenta["id_cuenta"])
    if not roles:
        raise AutenticacionError("La cuenta no tiene roles asignados.")
    return SesionUsuario(cuenta["id_cuenta"], cuenta["id_trabajador"],
                         cuenta["usuario"], cuenta["nombre_trabajador"], roles)


def tiene_permiso(roles: set[str] | frozenset[str], permiso: str) -> bool:
    if permiso == PERMISO_CONSULTAR:
        return bool({ROL_ADMIN, ROL_CONSULTA} & set(roles))
    if permiso == PERMISO_ESCRIBIR:
        return ROL_ADMIN in roles
    return False


def exigir_permiso(roles: set[str] | frozenset[str], permiso: str) -> None:
    if not tiene_permiso(roles, permiso):
        raise AutorizacionError("No tiene permiso para ejecutar esta operación.")


def guardar_sesion(state, sesion: SesionUsuario) -> None:
    state["autenticado"] = True
    state["id_cuenta"] = sesion.id_cuenta
    state["id_trabajador"] = sesion.id_trabajador
    state["usuario"] = sesion.usuario
    state["nombre_trabajador"] = sesion.nombre_trabajador
    state["roles"] = set(sesion.roles)


def cerrar_sesion(state) -> None:
    for clave in ("autenticado", "id_cuenta", "id_trabajador", "usuario",
                  "nombre_trabajador", "roles"):
        state.pop(clave, None)
