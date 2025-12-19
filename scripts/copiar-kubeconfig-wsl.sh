#!/bin/bash
# Script para copiar kubeconfig desde Windows a WSL

set -e

CLUSTER_NAME="${1:-cluster-acs}"
WSL_TMP="/tmp/kubeconfig-${CLUSTER_NAME}"
WIN_TMP="/mnt/c/tmp/kubeconfig-${CLUSTER_NAME}"

echo "=========================================="
echo "Copiando kubeconfig a WSL"
echo "=========================================="
echo ""

# Verificar si existe en Windows /tmp
if [ -f "${WIN_TMP}" ]; then
    echo "✅ Encontrado en Windows: ${WIN_TMP}"
    cp "${WIN_TMP}" "${WSL_TMP}"
    chmod 600 "${WSL_TMP}"
    echo "✅ Copiado a WSL: ${WSL_TMP}"
    exit 0
fi

# Verificar si existe en WSL /tmp
if [ -f "${WSL_TMP}" ]; then
    echo "✅ Ya existe en WSL: ${WSL_TMP}"
    exit 0
fi

echo "❌ No se encontró el kubeconfig en ninguna ubicación"
echo ""
echo "Por favor, copia el kubeconfig manualmente:"
echo "  cp /mnt/c/tmp/kubeconfig-${CLUSTER_NAME} ${WSL_TMP}"
echo "  chmod 600 ${WSL_TMP}"
echo ""
exit 1

