import os
import time
from functools import lru_cache

from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine, URL
from sqlalchemy.exc import SQLAlchemyError


def _required(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Falta la variable de entorno obligatoria: {name}")
    return value


@lru_cache(maxsize=1)
def get_engine() -> Engine:
    url = URL.create(
        drivername="mysql+pymysql",
        username=_required("DB_USER"),
        password=_required("DB_PASSWORD"),
        host=os.getenv("DB_HOST", "db"),
        port=int(os.getenv("DB_PORT", "3306")),
        database=os.getenv("DB_NAME", "caso5_colecciones"),
        query={"charset": "utf8mb4"},
    )
    return create_engine(
        url,
        pool_pre_ping=True,
        pool_recycle=1800,
        connect_args={"connect_timeout": 5},
    )


def wait_for_mysql(max_attempts: int = 10, delay_seconds: float = 2.0) -> bool:
    """Espera acotada para que MySQL acepte conexiones."""
    for attempt in range(1, max_attempts + 1):
        try:
            with get_engine().connect() as connection:
                connection.execute(text("SELECT 1"))
            return True
        except (SQLAlchemyError, OSError, RuntimeError):
            if attempt < max_attempts:
                time.sleep(delay_seconds)
    return False
