from datetime import date
from decimal import Decimal
import pandas as pd
import streamlit as st
from sqlalchemy.exc import IntegrityError, SQLAlchemyError

from db.connection import get_engine, wait_for_mysql
from db.metrics_dao import count_clientes, count_ventas
from db.operaciones_dao import (
    actualizar_coleccion, actualizar_pieza, buscar_colecciones, buscar_piezas,
    crear_coleccion, crear_evaluacion, crear_pieza, eliminar_coleccion,
    eliminar_pieza, listar_clientes, listar_piezas_activas, listar_trabajadores,
)
from services.auth_service import (
    AutenticacionError, AutorizacionError, PERMISO_ESCRIBIR, autenticar,
    cerrar_sesion, exigir_permiso, guardar_sesion,
)
from services.operaciones_service import (
    ValidacionError, decimal_no_negativo, mensaje_integridad, registrar_venta,
    texto_obligatorio,
)

st.set_page_config(page_title="Caso 5 - Colecciones", page_icon="💎", layout="wide")
st.title("Sistema de Venta de Minerales y Gemas de Colección")
st.caption("Video 7 · Venta transaccional y CRUD de colección y pieza")

if not wait_for_mysql():
    st.error("MySQL aún no está disponible.")
    st.code("docker compose ps\ndocker compose logs --tail=100 db")
    st.stop()
engine = get_engine()

if not st.session_state.get("autenticado", False):
    st.subheader("Inicio de sesión")
    with st.form("login", clear_on_submit=False):
        login_usuario = st.text_input("Usuario", max_chars=80)
        login_password = st.text_input("Contraseña", type="password")
        login_ok = st.form_submit_button("Ingresar", type="primary")
    if login_ok:
        try:
            guardar_sesion(st.session_state, autenticar(engine, login_usuario, login_password))
            st.rerun()
        except AutenticacionError as exc:
            st.error(str(exc))
    st.stop()

roles = set(st.session_state.get("roles", set()))
es_admin = "ADMINISTRADOR" in roles
paginas = ["Inicio", "Colecciones", "Piezas"]
if es_admin:
    paginas[1:1] = ["Registrar venta"]
    paginas.append("Evaluaciones")

with st.sidebar:
    st.write(f"Usuario: **{st.session_state['usuario']}**")
    st.caption("Roles: " + ", ".join(sorted(roles)))
    if st.button("Cerrar sesión"):
        cerrar_sesion(st.session_state)
        st.rerun()
    pagina = st.radio("Navegación", paginas)

# La navegación no basta: cada escritura vuelve a exigir ADMINISTRADOR.



def mostrar_error(exc: Exception, entidad: str) -> None:
    if isinstance(exc, IntegrityError):
        st.error(mensaje_integridad(exc, entidad))
    elif isinstance(exc, ValidacionError):
        st.warning(str(exc))
    else:
        st.error(f"No fue posible completar la operación sobre {entidad}.")

if pagina == "Inicio":
    c1, c2 = st.columns(2)
    c1.metric("Clientes registrados", count_clientes(engine))
    c2.metric("Ventas registradas", count_ventas(engine))
    st.success("Conexión con MySQL establecida correctamente.")

elif pagina == "Registrar venta":
    exigir_permiso(roles, PERMISO_ESCRIBIR)
    clientes, trabajadores, piezas = listar_clientes(engine), listar_trabajadores(engine), listar_piezas_activas(engine)
    if not clientes or not trabajadores or not piezas:
        st.warning("Se requieren clientes, trabajadores y piezas activas antes de registrar una venta.")
        st.stop()
    cli = {f"{x['id_cliente']} · {x['nombre_razon_social']}": x['id_cliente'] for x in clientes}
    tra = {f"{x['id_trabajador']} · {x['nombre']}": x['id_trabajador'] for x in trabajadores}
    pie = {f"{x['id_pieza']} · {x['nombre_comercial']} · {x['coleccion']}": x['id_pieza'] for x in piezas}
    with st.form("venta"):
        a,b,c = st.columns(3)
        id_venta = a.text_input("ID de venta", max_chars=12)
        cliente_label = b.selectbox("Cliente", list(cli))
        trabajador_label = c.selectbox("Gestor comercial", list(tra))
        fecha = st.date_input("Fecha", value=date.today())
        seleccion = st.multiselect("Piezas", list(pie))
        detalles=[]
        for etiqueta in seleccion:
            x,y=st.columns([1,2])
            precio=x.number_input(f"Precio · {etiqueta}", min_value=0.0, step=1000.0, key=f"p_{pie[etiqueta]}")
            condiciones=y.text_input(f"Condiciones · {etiqueta}", max_chars=250, key=f"c_{pie[etiqueta]}")
            detalles.append({"id_pieza":pie[etiqueta],"precio_venta":precio,"condiciones":condiciones})
        enviar=st.form_submit_button("Registrar venta", type="primary")
    if enviar:
        try:
            total=registrar_venta(engine,id_venta,cli[cliente_label],tra[trabajador_label],fecha,detalles)
            st.success(f"Venta {id_venta} registrada. Total: ${total:,.2f}")
        except (ValidacionError,IntegrityError,SQLAlchemyError) as exc: mostrar_error(exc,"la venta")

elif pagina == "Colecciones":
    st.subheader("CRUD de colecciones")
    termino=st.text_input("Buscar por ID, nombre o temática")
    datos=buscar_colecciones(engine,termino)
    st.dataframe(pd.DataFrame(datos),use_container_width=True,hide_index=True)
    if not es_admin:
        st.info("Rol CONSULTA: visualización sin permisos de modificación.")
        st.stop()
    tab1,tab2,tab3=st.tabs(["Crear","Modificar","Eliminar"])
    with tab1:
        with st.form("crear_coleccion"):
            i=st.text_input("ID",max_chars=10); n=st.text_input("Nombre"); t=st.text_input("Temática")
            f=st.date_input("Fecha de creación",value=date.today()); r=st.text_input("Responsable")
            e=st.text_input("Estado de conservación"); a=st.checkbox("Activa",value=True)
            ok=st.form_submit_button("Crear")
        if ok:
            try:
                exigir_permiso(roles, PERMISO_ESCRIBIR); crear_coleccion(engine,{"id_coleccion":texto_obligatorio(i,"ID",10),"nombre":texto_obligatorio(n,"Nombre",100),"tematica":texto_obligatorio(t,"Temática",100),"fecha_creacion":f,"responsable":texto_obligatorio(r,"Responsable",100),"estado_conservacion":texto_obligatorio(e,"Estado",40),"activa":a}); st.success("Colección creada."); st.rerun()
            except (ValidacionError,IntegrityError,SQLAlchemyError) as exc: mostrar_error(exc,"la colección")
    with tab2:
        if datos:
            opciones={f"{x['id_coleccion']} · {x['nombre']}":x for x in datos}; sel=st.selectbox("Colección",list(opciones),key="cu"); x=opciones[sel]
            with st.form("editar_coleccion"):
                n=st.text_input("Nombre",x["nombre"]); t=st.text_input("Temática",x["tematica"]); f=st.date_input("Fecha",x["fecha_creacion"]); r=st.text_input("Responsable",x["responsable"]); e=st.text_input("Estado",x["estado_conservacion"]); a=st.checkbox("Activa",bool(x["activa"])); ok=st.form_submit_button("Guardar")
            if ok:
                try:
                    exigir_permiso(roles, PERMISO_ESCRIBIR); actualizar_coleccion(engine,x["id_coleccion"],{"nombre":texto_obligatorio(n,"Nombre",100),"tematica":texto_obligatorio(t,"Temática",100),"fecha_creacion":f,"responsable":texto_obligatorio(r,"Responsable",100),"estado_conservacion":texto_obligatorio(e,"Estado",40),"activa":a}); st.success("Colección actualizada."); st.rerun()
                except (ValidacionError,IntegrityError,SQLAlchemyError) as exc: mostrar_error(exc,"la colección")
    with tab3:
        if datos:
            ids=[x["id_coleccion"] for x in datos]; ident=st.selectbox("ID a eliminar",ids)
            if st.button("Eliminar colección",type="secondary"):
                try: exigir_permiso(roles, PERMISO_ESCRIBIR); eliminar_coleccion(engine,ident); st.success("Colección eliminada."); st.rerun()
                except (IntegrityError,SQLAlchemyError) as exc: mostrar_error(exc,"la colección")

elif pagina == "Piezas":
    st.subheader("CRUD de piezas")
    colecciones=buscar_colecciones(engine); cmap={f"{x['id_coleccion']} · {x['nombre']}":x['id_coleccion'] for x in colecciones}
    if not cmap: st.warning("Primero debe crear una colección."); st.stop()
    termino=st.text_input("Buscar por ID, nombre o colección"); datos=buscar_piezas(engine,termino)
    st.dataframe(pd.DataFrame(datos),use_container_width=True,hide_index=True)
    if not es_admin:
        st.info("Rol CONSULTA: visualización sin permisos de modificación.")
        st.stop()
    tab1,tab2,tab3=st.tabs(["Crear","Modificar","Eliminar"])
    def formulario_pieza(prefijo, x=None):
        x=x or {}; c1,c2=st.columns(2)
        nombre=c1.text_input("Nombre comercial",x.get("nombre_comercial",""),key=prefijo+"n")
        coleccion_actual=next((k for k,v in cmap.items() if v==x.get("id_coleccion")),list(cmap)[0])
        coleccion=c2.selectbox("Colección",list(cmap),index=list(cmap).index(coleccion_actual),key=prefijo+"c")
        pais=c1.text_input("País",x.get("procedencia_pais",""),key=prefijo+"pa")
        region=c2.text_input("Región",x.get("procedencia_region") or "",key=prefijo+"r")
        localidad=c1.text_input("Localidad",x.get("procedencia_localidad") or "",key=prefijo+"l")
        fecha=c2.date_input("Fecha de adquisición",x.get("fecha_adquisicion",date.today()),key=prefijo+"f")
        valor=c1.number_input("Valor estimado",min_value=0.0,value=float(x.get("valor_estimado",0)),key=prefijo+"v")
        estado=c2.text_input("Estado de conservación",x.get("estado_conservacion",""),key=prefijo+"e")
        rareza=c1.text_input("Nivel de rareza",x.get("nivel_rareza",""),key=prefijo+"ra")
        activa=c2.checkbox("Activa",bool(x.get("activa",True)),key=prefijo+"a")
        return {"id_coleccion":cmap[coleccion],"nombre_comercial":texto_obligatorio(nombre,"Nombre",100),"procedencia_pais":texto_obligatorio(pais,"País",60),"procedencia_region":region.strip() or None,"procedencia_localidad":localidad.strip() or None,"fecha_adquisicion":fecha,"valor_estimado":decimal_no_negativo(valor,"Valor estimado"),"estado_conservacion":texto_obligatorio(estado,"Estado",40),"nivel_rareza":texto_obligatorio(rareza,"Rareza",30),"activa":activa}
    with tab1:
        with st.form("crear_pieza"):
            ident=st.text_input("ID de pieza",max_chars=10)
            try: payload=formulario_pieza("pc_")
            except ValidacionError: payload=None
            ok=st.form_submit_button("Crear")
        if ok:
            try:
                payload=formulario_pieza # evita uso; Streamlit ya capturó valores
                # reconstrucción desde session_state
                datos_n={"id_coleccion":cmap[st.session_state.pc_c],"nombre_comercial":texto_obligatorio(st.session_state.pc_n,"Nombre",100),"procedencia_pais":texto_obligatorio(st.session_state.pc_pa,"País",60),"procedencia_region":st.session_state.pc_r.strip() or None,"procedencia_localidad":st.session_state.pc_l.strip() or None,"fecha_adquisicion":st.session_state.pc_f,"valor_estimado":decimal_no_negativo(st.session_state.pc_v,"Valor estimado"),"estado_conservacion":texto_obligatorio(st.session_state.pc_e,"Estado",40),"nivel_rareza":texto_obligatorio(st.session_state.pc_ra,"Rareza",30),"activa":st.session_state.pc_a,"id_pieza":texto_obligatorio(ident,"ID",10)}
                exigir_permiso(roles, PERMISO_ESCRIBIR); crear_pieza(engine,datos_n); st.success("Pieza creada."); st.rerun()
            except (ValidacionError,IntegrityError,SQLAlchemyError) as exc: mostrar_error(exc,"la pieza")
    with tab2:
        if datos:
            opts={f"{x['id_pieza']} · {x['nombre_comercial']}":x for x in datos}; lab=st.selectbox("Pieza",list(opts)); x=opts[lab]
            with st.form("editar_pieza"):
                try: payload=formulario_pieza("pu_",x)
                except ValidacionError: payload=None
                ok=st.form_submit_button("Guardar")
            if ok:
                try:
                    exigir_permiso(roles, PERMISO_ESCRIBIR); actualizar_pieza(engine,x["id_pieza"],payload); st.success("Pieza actualizada."); st.rerun()
                except (ValidacionError,IntegrityError,SQLAlchemyError) as exc: mostrar_error(exc,"la pieza")
    with tab3:
        if datos:
            ident=st.selectbox("ID a eliminar",[x["id_pieza"] for x in datos])
            if st.button("Eliminar pieza"):
                try: exigir_permiso(roles, PERMISO_ESCRIBIR); eliminar_pieza(engine,ident); st.success("Pieza eliminada."); st.rerun()
                except (IntegrityError,SQLAlchemyError) as exc: mostrar_error(exc,"la pieza")

else:
    exigir_permiso(roles, PERMISO_ESCRIBIR)
    st.subheader("Registrar evaluación")
    with st.form("evaluacion"):
        iv=st.text_input("ID de venta",max_chars=12); ne=st.number_input("Número",min_value=1,step=1)
        fe=st.date_input("Fecha",value=date.today()); ca=st.slider("Calificación",1,5,5); co=st.text_area("Comentario",max_chars=500)
        ok=st.form_submit_button("Registrar")
    if ok:
        try:
            exigir_permiso(roles, PERMISO_ESCRIBIR); crear_evaluacion(engine,{"id_venta":texto_obligatorio(iv,"Venta",12),"nro_evaluacion":int(ne),"fecha":fe,"calificacion":int(ca),"comentario":co.strip() or None}); st.success("Evaluación registrada.")
        except (ValidacionError,IntegrityError,SQLAlchemyError) as exc: mostrar_error(exc,"la evaluación")
