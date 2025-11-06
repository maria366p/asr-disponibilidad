#!/bin/bash
# Simula falla técnica (inventario inaccesible)

echo "⚠️  Desactivando servicio de Inventario (falla técnica)..."
sudo systemctl stop inventario.service 2>/dev/null || pkill -f "uvicorn app:app" || true
echo "Inventario detenido."
