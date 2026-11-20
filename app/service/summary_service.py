from dataclasses import dataclass

from sqlalchemy.engine import Engine

from db.metrics_dao import count_clientes, count_ventas


@dataclass(frozen=True)
class HomeSummary:
    clientes: int
    ventas: int


def get_home_summary(engine: Engine) -> HomeSummary:
    return HomeSummary(
        clientes=count_clientes(engine),
        ventas=count_ventas(engine),
    )
