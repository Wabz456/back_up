# Control de usuarios - Caso 5

## Decisión D10 propuesta
- ADMINISTRADOR: consulta y operaciones de escritura del formulario y CRUD.
- CONSULTA: Inicio, listado de colecciones y listado de piezas, sin escritura.

## Archivos
- `app/main.py`: conserva Video 7 y agrega login, logout y navegación autorizada.
- `app/db/auth_dao.py`: consultas parametrizadas sobre `cuenta_usuario`, `rol`, `usuario_rol`.
- `app/services/auth_service.py`: bcrypt, sesión y permisos.
- `sql/03_agregar_password_hash.sql`: migración incremental no destructiva.
- `scripts/crear_usuarios_demo.py`: configura dos cuentas existentes mediante entrada interactiva.
- `tests/test_auth_service.py`: autenticación, contraseña incorrecta, roles y cierre.
- `requirements.txt`: agrega bcrypt.

## Ejecución
```bash
docker compose exec -T db mysql -uroot -p"$MYSQL_ROOT_PASSWORD" < sql/03_agregar_password_hash.sql
docker compose build app
docker compose up -d --no-deps app
docker compose exec -it app python scripts/crear_usuarios_demo.py
docker compose exec app pytest -v tests/test_auth_service.py
```
En Codespaces, abrir el puerto 8501 desde la pestaña Ports.

## Verificación manual
1. Credenciales válidas: abre Inicio.
2. Contraseña incorrecta y usuario inexistente: mismo mensaje genérico.
3. ADMINISTRADOR: ve Registrar venta, CRUD y Evaluaciones.
4. CONSULTA: solo Inicio, Colecciones y Piezas; sin botones de escritura.
5. Llamar `exigir_permiso({"CONSULTA"}, "ESCRIBIR")` produce `AutorizacionError`.
6. Cerrar sesión limpia las claves de sesión y regresa al login.
