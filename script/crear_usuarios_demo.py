"""Configura de forma interactiva una cuenta ADMINISTRADOR y una CONSULTA."""
from getpass import getpass
from sqlalchemy import text
from db.connection import get_engine
from db.auth_dao import actualizar_hash, asignar_rol, buscar_rol_por_nombre
from services.auth_service import hash_password


def configurar(nombre_rol: str) -> None:
    print(f"\nConfiguración de cuenta con rol {nombre_rol}")
    usuario = input("Usuario existente en cuenta_usuario: ").strip()
    password = getpass("Nueva contraseña (mínimo 8 caracteres): ")
    confirmacion = getpass("Repita la contraseña: ")
    if password != confirmacion:
        raise ValueError("Las contraseñas no coinciden.")
    password_hash = hash_password(password)
    engine = get_engine()
    with engine.begin() as cn:
        id_cuenta = cn.execute(
            text("""SELECT id_cuenta FROM cuenta_usuario
                    WHERE usuario=:usuario AND activa=TRUE"""),
            {"usuario": usuario},
        ).scalar_one_or_none()
        if not id_cuenta:
            raise ValueError("El usuario no existe o la cuenta está inactiva.")
        id_rol = buscar_rol_por_nombre(cn, nombre_rol)
        if not id_rol:
            raise ValueError(f"No existe el rol {nombre_rol}.")
        actualizar_hash(cn, id_cuenta, password_hash)
        asignar_rol(cn, id_cuenta, id_rol)
    print(f"Cuenta {usuario} configurada sin mostrar ni guardar la contraseña.")

if __name__ == "__main__":
    configurar("ADMINISTRADOR")
    configurar("CONSULTA")
