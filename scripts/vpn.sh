#!/bin/bash
# Gestion VPN - Rotation manuelle ou automatique

ACTION=${1:-rotate}

case $ACTION in
  rotate|manual)
    echo "Rotation du serveur VPN..."
    docker-compose restart gluetun
    sleep 10
    NEW_IP=$(docker exec gluetun wget -qO- https://ipinfo.io/ip 2>/dev/null)
    echo "Nouvelle IP VPN: $NEW_IP"
    ;;
    
  auto)
    echo "Rotation automatique VPN toutes les 6 heures"
    while true; do
      echo "[$(date)] Rotation VPN..."
      docker-compose restart gluetun
      sleep 21600  # 6 heures
    done
    ;;
    
  check)
    LOCAL_IP=$(curl -s https://ipinfo.io/ip)
    VPN_IP=$(docker exec gluetun wget -qO- https://ipinfo.io/ip 2>/dev/null)
    echo "IP locale: $LOCAL_IP"
    echo "IP VPN: $VPN_IP"
    [ "$VPN_IP" != "$LOCAL_IP" ] && echo "VPN actif" || echo "VPN inactif"
    ;;
    
  *)
    echo "Usage: $0 {rotate|auto|check}"
    exit 1
    ;;
esac
