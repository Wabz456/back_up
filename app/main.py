import streamlit as st
from sqlalchemy.exc import SQLAlchemyError

from db.connection import get_engine, wait_for_mysql
from services.summary_service import get_home_summary

st.set_page_config(page_title="Caso 5 - Colecciones", page_icon="💎", layout="wide")
st.title("Sistema de Venta de Minerales y Gemas de Colección")
st.caption("Proyecto Fase 2 - aplicación inicial con arquitectura de tres capas")

if not wait_for_mysql():
    st.warning(
        "MySQL todavía no está disponible. Verifique el contenedor db y vuelva a cargar la página."
    )
    st.code("docker compose ps\ndocker compose logs --tail=100 db")
    st.stop()

try:
    summary = get_home_summary(get_engine())
except (SQLAlchemyError, RuntimeError) as exc:
    st.error("No fue posible consultar la base de datos.")
    st.exception(exc)
    st.stop()

st.success("Conexión con MySQL establecida correctamente.")

col1, col2 = st.columns(2)

col1.metric(
    label="Clientes registrados",
    value=summary.clientes,
)

col2.metric(
    label="Ventas registradas",
    value=summary.ventas,
)
#st.success("Conexión con MySQL establecida correctamente.")
#col1, col2 = st.columns(2)
#col1.metric("Clientes registrados", summary.clientes)
#col2.metric("Ventas registradas", summary.ventas)

#st.info(
  #  "El DDL recibido no contiene una tabla de órdenes de reparación. "
  #  "Por fidelidad al modelo real, esta versión muestra la cantidad de ventas."
#)
