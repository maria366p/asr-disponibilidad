#!/bin/bash
# Carga inicial de productos (Dataset base)
# ASR Disponibilidad - María Paula Ospina

# Uso: ./seed_1000.sh <IP_KONG[:PUERTO]>
# Ejemplo: ./seed_1000.sh 98.91.199.204:8000

KONG_IP=$1
if [ -z "$KONG_IP" ]; then
  echo "Uso: ./seed_1000.sh <IP_KONG[:PUERTO]>"
  echo "Ejemplo: ./seed_1000.sh 98.91.199.204:8000"
  exit 1
fi

echo "🚀 Sembrando 1000 productos en el inventario a través de Kong ($KONG_IP)..."

success=0
fail=0

for i in $(seq 1 1000); do
  response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://$KONG_IP/inventario/add/P$i/100/5.5")
  if [ "$response" -eq 200 ]; then
    success=$((success+1))
  else
    fail=$((fail+1))
  fi
done

echo "✅ Carga completada"
echo "   Productos creados correctamente: $success"
echo "   Fallidos: $fail"
