from types import SimpleNamespace
from unittest.mock import Mock, patch
import pytest
from services.auth_service import (
    AutenticacionError, AutorizacionError, PERMISO_CONSULTAR, PERMISO_ESCRIBIR,
    autenticar, cerrar_sesion, exigir_permiso, guardar_sesion, hash_password,
    verificar_password,
)

def test_hash_y_password_correcta():
    h = hash_password("ClaveDemo123")
    assert h != "ClaveDemo123"
    assert verificar_password("ClaveDemo123", h)
    assert not verificar_password("incorrecta", h)

def test_usuario_inexistente():
    with patch("services.auth_service.buscar_cuenta_por_usuario", return_value=None):
        with pytest.raises(AutenticacionError): autenticar(Mock(), "nadie", "ClaveDemo123")

def test_login_valido():
    cuenta={"id_cuenta":"CTA001","id_trabajador":"TRA001","usuario":"usuario001",
            "nombre_trabajador":"Persona Demo","activa":True,
            "password_hash":hash_password("ClaveDemo123")}
    with patch("services.auth_service.buscar_cuenta_por_usuario", return_value=cuenta), \
         patch("services.auth_service.listar_roles_de_cuenta", return_value=frozenset({"ADMINISTRADOR"})):
        sesion=autenticar(Mock(),"usuario001","ClaveDemo123")
        assert "ADMINISTRADOR" in sesion.roles

def test_permisos_admin_y_consulta():
    exigir_permiso({"ADMINISTRADOR"}, PERMISO_ESCRIBIR)
    exigir_permiso({"CONSULTA"}, PERMISO_CONSULTAR)
    with pytest.raises(AutorizacionError): exigir_permiso({"CONSULTA"}, PERMISO_ESCRIBIR)

def test_cierre_sesion_no_conserva_password():
    state={}
    sesion=SimpleNamespace(id_cuenta="CTA001",id_trabajador="TRA001",usuario="u",
                           nombre_trabajador="Demo",roles=frozenset({"CONSULTA"}))
    guardar_sesion(state,sesion)
    assert "password" not in state and "password_hash" not in state
    cerrar_sesion(state)
    assert not state
