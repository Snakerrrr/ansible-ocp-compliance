#!/bin/bash
# Script para renovar kubeconfig de un managed cluster
# Actualiza el token en el kubeconfig si está expirado o próximo a expirar

set -e

CLUSTER_NAME="${1:-cluster-acs}"
KUBECONFIG_PATH="${2:-/tmp/kubeconfig-${CLUSTER_NAME}}"

echo "=========================================="
echo "Renovando kubeconfig del managed cluster"
echo "=========================================="
echo ""
echo "Cluster: ${CLUSTER_NAME}"
echo "Kubeconfig: ${KUBECONFIG_PATH}"
echo ""

# Verificar que el kubeconfig existe
if [ ! -f "${KUBECONFIG_PATH}" ]; then
    echo "❌ Error: El kubeconfig no existe en ${KUBECONFIG_PATH}"
    echo ""
    echo "Primero obtén el kubeconfig:"
    echo "  oc login <api-server-url>"
    echo "  oc config view --minify --raw > ${KUBECONFIG_PATH}"
    exit 1
fi

# Extraer información del kubeconfig actual
API_SERVER=$(grep -A 2 "server:" "${KUBECONFIG_PATH}" | grep "server:" | awk '{print $2}' | head -1)
CURRENT_CONTEXT=$(grep "current-context:" "${KUBECONFIG_PATH}" | awk '{print $2}')

if [ -z "${API_SERVER}" ]; then
    echo "❌ Error: No se pudo extraer el API server del kubeconfig"
    exit 1
fi

echo "API Server: ${API_SERVER}"
echo "Contexto actual: ${CURRENT_CONTEXT}"
echo ""

# Verificar si el token está expirado o próximo a expirar
echo "Verificando validez del token..."
if KUBECONFIG="${KUBECONFIG_PATH}" oc whoami &>/dev/null; then
    TOKEN_EXPIRY=$(KUBECONFIG="${KUBECONFIG_PATH}" oc whoami --show-token 2>/dev/null | cut -d. -f2 | base64 -d 2>/dev/null | jq -r '.exp' 2>/dev/null || echo "")
    
    if [ -n "${TOKEN_EXPIRY}" ] && [ "${TOKEN_EXPIRY}" != "null" ]; then
        CURRENT_TIME=$(date +%s)
        EXPIRY_TIME=${TOKEN_EXPIRY}
        TIME_UNTIL_EXPIRY=$((EXPIRY_TIME - CURRENT_TIME))
        HOURS_UNTIL_EXPIRY=$((TIME_UNTIL_EXPIRY / 3600))
        
        echo "Token válido. Expira en: ${HOURS_UNTIL_EXPIRY} horas"
        
        # Si expira en menos de 24 horas, renovar
        if [ ${TIME_UNTIL_EXPIRY} -lt 86400 ]; then
            echo "⚠️  El token expira pronto (menos de 24 horas). Renovando..."
        else
            echo "✅ El token es válido por más de 24 horas. No es necesario renovar."
            exit 0
        fi
    else
        echo "⚠️  No se pudo verificar la expiración del token. Intentando renovar..."
    fi
else
    echo "⚠️  El token parece estar expirado o inválido. Renovando..."
fi

# Intentar renovar el token
echo ""
echo "Renovando kubeconfig..."

# Opción 1: Si tenemos acceso directo al cluster, hacer login nuevamente
if command -v oc &> /dev/null; then
    echo "Intentando renovar mediante oc login..."
    echo ""
    echo "Por favor, ejecuta manualmente:"
    echo "  oc login ${API_SERVER}"
    echo "  oc config view --minify --raw > ${KUBECONFIG_PATH}"
    echo "  chmod 600 ${KUBECONFIG_PATH}"
    echo ""
    echo "O si prefieres, este script puede intentar renovarlo automáticamente."
    read -p "¿Deseas que el script intente renovar el kubeconfig automáticamente? (s/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        # Intentar usar el kubeconfig actual para hacer login (puede fallar si está expirado)
        if KUBECONFIG="${KUBECONFIG_PATH}" oc login "${API_SERVER}" --token="$(KUBECONFIG="${KUBECONFIG_PATH}" oc whoami --show-token 2>/dev/null || echo '')" &>/dev/null; then
            KUBECONFIG="${KUBECONFIG_PATH}" oc config view --minify --raw > "${KUBECONFIG_PATH}.new"
            mv "${KUBECONFIG_PATH}.new" "${KUBECONFIG_PATH}"
            chmod 600 "${KUBECONFIG_PATH}"
            echo "✅ Kubeconfig renovado exitosamente"
        else
            echo "❌ No se pudo renovar automáticamente. El token puede estar completamente expirado."
            echo ""
            echo "Renueva manualmente:"
            echo "  1. Loguearte al cluster: oc login ${API_SERVER}"
            echo "  2. Exportar kubeconfig: oc config view --minify --raw > ${KUBECONFIG_PATH}"
            echo "  3. Ajustar permisos: chmod 600 ${KUBECONFIG_PATH}"
            exit 1
        fi
    else
        echo "Renovación cancelada. Renueva manualmente cuando sea necesario."
        exit 0
    fi
else
    echo "❌ oc no está disponible. Renueva manualmente el kubeconfig."
    exit 1
fi

