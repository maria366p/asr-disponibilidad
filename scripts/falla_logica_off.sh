#!/bin/bash
# Desactiva modo de falla lógica

echo "🟢 Restaurando servicio original de Inventario..."
if [ -f /opt/inventario/app_backup.py ]; then
  mv /opt/inventario/app_backup.py /opt/inventario/app.py
fi

pkill -f "uvicorn app:app"
cd /opt/inventario
source venv/bin/activate
nohup venv/bin/uvicorn app:app --host 0.0.0.0 --port 8081 >/dev/null 2>&1 &
echo "Servicio restaurado."
