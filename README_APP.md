# Aplicación inicial - Proyecto Fase 2

## Arquitectura

- `main.py`: presentación Streamlit.
- `services/`: lógica de aplicación.
- `db/connection.py`: motor SQLAlchemy y espera de MySQL.
- `db/metrics_dao.py`: consultas DAO sobre `cliente` y `venta`.
- `tests/`: pruebas unitarias e integración opcional.


## Preparación

```bash
cp .env.example .env
```

Edite `.env` y use una contraseña local. Para la configuración mínima, `DB_PASSWORD` debe coincidir con `MYSQL_ROOT_PASSWORD`. No versione `.env`.

> Si el volumen `mysql_data` ya fue inicializado y poblado, no ejecute `docker compose down -v`, porque eliminaría los datos.

## Ejecución

```bash
docker compose up -d --build
docker compose ps
docker compose logs --tail=100 db
docker compose logs --tail=100 app
```

En GitHub Codespaces, abra la vista **Ports**, localice el puerto `8501` y seleccione **Open in Browser**. phpMyAdmin continúa disponible en el puerto `8090`.

## Verificación

La página debe mostrar conexión exitosa, cantidad de clientes y cantidad de ventas. Verificación SQL equivalente:

```bash
docker compose exec db mysql -uroot -p -D caso5_colecciones -e \
  "SELECT COUNT(*) AS clientes FROM cliente; SELECT COUNT(*) AS ventas FROM venta;"
```

## Pruebas

Unitarias, sin MySQL:

```bash
docker compose exec app pytest -q tests/test_summary_service.py
```

Integración contra el servicio `db`:

```bash
docker compose exec -e RUN_DB_TESTS=1 app pytest -q tests/test_integration_db.py
```

## Diagnóstico

```bash
docker compose ps
docker compose logs -f app
docker compose logs -f db
docker compose logs --tail=100 phpmyadmin
docker inspect --format='{{json .State.Health}}' $(docker compose ps -q db)
```

## Git

```bash
git status
git add main.py db services tests requirements.txt Dockerfile docker-compose.yml .env.example .gitignore README_APP.md
git diff --cached
git commit -m "feat: iniciar app Streamlit con arquitectura de tres capas"
git push origin HEAD
```

En GitHub, abra el commit más reciente y confirme que `.env` no aparece, que sí aparecen `.env.example`, `Dockerfile`, `requirements.txt`, `main.py`, `db/`, `services/` y `tests/`.
