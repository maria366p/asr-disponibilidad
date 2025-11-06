#!/bin/bash
# Prueba individual de salida a través de Kong
# Mide latencia de respuesta

KONG_IP=$1
if [ -z "$KONG_IP" ]; then
  echo "Uso: ./probar_salida.sh <IP_KONG>"
  exit 1
fi

echo "Ejecutando prueba de salida..."
for i in {1..5}; do
  echo "Intento $i:"
  time curl -s -o /dev/null -w "%{http_code}\n" \
    -X POST http://$KONG_IP:8000/inventario/salida/ \
    -d "producto=P1" -d "cantidad=1"
  sleep 1
done
