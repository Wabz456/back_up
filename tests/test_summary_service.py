from unittest.mock import patch

from db.metrics_dao import count_clientes, count_ventas
from services.summary_service import get_home_summary


class FakeConnection:
    def __init__(self, value: int):
        self.value = value

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def scalar(self, statement):
        return self.value


class FakeEngine:
    def __init__(self, value: int):
        self.value = value

    def connect(self):
        return FakeConnection(self.value)


def test_count_clientes_returns_integer():
    assert count_clientes(FakeEngine(220)) == 220


def test_count_ventas_returns_integer():
    assert count_ventas(FakeEngine(420)) == 420


def test_service_combines_dao_results():
    with patch("services.summary_service.count_clientes", return_value=220), patch(
        "services.summary_service.count_ventas", return_value=420
    ):
        result = get_home_summary(FakeEngine(0))
    assert result.clientes == 220
    assert result.ventas == 420
