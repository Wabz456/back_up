import os

import pytest
from sqlalchemy import text

from db.connection import get_engine
from db.metrics_dao import count_clientes, count_ventas

pytestmark = pytest.mark.skipif(
    os.getenv("RUN_DB_TESTS") != "1",
    reason="Defina RUN_DB_TESTS=1 para ejecutar pruebas contra MySQL",
)


def test_database_connection_and_real_counts():
    engine = get_engine()
    with engine.connect() as connection:
        assert connection.scalar(text("SELECT 1")) == 1
    assert count_clientes(engine) >= 0
    assert count_ventas(engine) >= 0
