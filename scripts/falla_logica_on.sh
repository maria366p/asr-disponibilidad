#!/bin/bash
# Activa modo de falla lógica (respuesta sin actualización real)

echo "⚠️  Activando modo de falla lógica en Inventario..."
if [ ! -f /opt/inventario/app_backup.py ]; then
  cp /opt/inventario/app.py /opt/inventario/app_backup.py
fi

cat <<EOF > /opt/inventario/app.py
from fastapi import FastAPI
app = FastAPI()

@app.get("/health/")
def h():
    return {"ok": True}

@app.post("/inventario/salida/")
def salida(producto: str, cantidad: int):
    # Falla lógica: no modifica stock, solo responde éxito
    return {"status": "ok", "mensaje": "registrado sin actualizar stock"}
EOF

pkill -f "uvicorn app:app"
cd /opt/inventario
source venv/bin/activate
nohup venv/bin/uvicorn app:app --host 0.0.0.0 --port 8081 >/dev/null 2>&1 &
echo "Modo de falla lógica activado."
