from sqlalchemy import text
from sqlalchemy.engine import Engine


def count_clientes(engine: Engine) -> int:
    """Cuenta registros de la tabla real cliente."""
    with engine.connect() as connection:
        return int(connection.scalar(text("SELECT COUNT(*) FROM cliente")) or 0)


def count_ventas(engine: Engine) -> int:
    """Cuenta registros de la tabla real venta."""
    with engine.connect() as connection:
        return int(
            connection.scalar(
                text("SELECT COUNT(*) FROM venta")
                ) or 0
        )
