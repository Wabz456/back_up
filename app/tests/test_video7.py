from datetime import date
from decimal import Decimal
from unittest.mock import MagicMock
import pytest
from services.operaciones_service import ValidacionError, decimal_no_negativo, registrar_venta, texto_obligatorio


def test_texto_obligatorio():
    assert texto_obligatorio("  gema  ", "Nombre", 10) == "gema"
    with pytest.raises(ValidacionError): texto_obligatorio("", "Nombre", 10)


def test_decimal_no_negativo():
    assert decimal_no_negativo("12.5", "Precio") == Decimal("12.50")
    with pytest.raises(ValidacionError): decimal_no_negativo(-1, "Precio")


def test_venta_exige_detalles():
    with pytest.raises(ValidacionError, match="al menos una"):
        registrar_venta(MagicMock(), "V1", "C1", "T1", date.today(), [])


def test_venta_rechaza_pieza_duplicada():
    detalles=[{"id_pieza":"P1","precio_venta":10},{"id_pieza":"P1","precio_venta":20}]
    with pytest.raises(ValidacionError, match="repetirse"):
        registrar_venta(MagicMock(), "V1", "C1", "T1", date.today(), detalles)
