#!/bin/bash
# Carga inicial de productos (Dataset base)
# ASR Disponibilidad - María Paula Ospina

KONG_IP=$1
if [ -z "$KONG_IP" ]; then
  echo "Uso: ./seed_1000.sh <IP_KONG>"
  exit 1
fi

echo "Sembrando 1000 productos en el inventario a través de Kong ($KONG_IP)..."

for i in $(seq 1 1000); do
  curl -s -X POST http://$KONG_IP:8000/inventario/create/ \
    -d "producto=P$i" -d "cantidad=100" -d "unidad=und" > /dev/null
done

echo "Carga completada ✅"
