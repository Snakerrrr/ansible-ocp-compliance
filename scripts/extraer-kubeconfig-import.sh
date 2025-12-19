#!/bin/bash
# Script de prueba para extraer kubeconfig desde secret cluster-*-import
# Ayuda a entender la estructura del import.yaml

set -e

CLUSTER_NAME="${1:-cluster-acs}"

echo "=========================================="
echo "Extrayendo kubeconfig desde secret de import"
echo "=========================================="
echo ""
echo "Cluster: ${CLUSTER_NAME}"
echo "Secret: ${CLUSTER_NAME}-import"
echo "Namespace: ${CLUSTER_NAME}"
echo ""

# Verificar que el secret existe
if ! oc get secret ${CLUSTER_NAME}-import -n ${CLUSTER_NAME} &>/dev/null; then
    echo "❌ Error: El secret '${CLUSTER_NAME}-import' no existe en el namespace '${CLUSTER_NAME}'"
    exit 1
fi

echo "✅ Secret encontrado"
echo ""

# Obtener import.yaml
echo "📄 Extrayendo import.yaml..."
IMPORT_YAML=$(oc get secret ${CLUSTER_NAME}-import -n ${CLUSTER_NAME} -o jsonpath='{.data.import\.yaml}' | base64 -d)

if [ -z "${IMPORT_YAML}" ]; then
    echo "❌ Error: El campo 'import.yaml' está vacío o no existe"
    exit 1
fi

echo "✅ import.yaml extraído (${#IMPORT_YAML} caracteres)"
echo ""

# Mostrar primeras líneas para entender la estructura
echo "📋 Primeras líneas del import.yaml:"
echo "----------------------------------------"
echo "${IMPORT_YAML}" | head -20
echo "----------------------------------------"
echo ""

# Intentar extraer kubeconfig
echo "🔍 Intentando extraer kubeconfig desde Secret bootstrap-hub-kubeconfig..."
echo ""

# El import.yaml contiene un Secret "bootstrap-hub-kubeconfig" con data.kubeconfig en base64
# Método 1: Extraer usando awk y sed
KUBECONFIG_B64=$(echo "${IMPORT_YAML}" | awk '/name: "bootstrap-hub-kubeconfig"/,/^---/' | grep 'kubeconfig:' | sed 's/.*kubeconfig: *"\([^"]*\)".*/\1/' | head -1)

if [ -n "${KUBECONFIG_B64}" ] && [ "${#KUBECONFIG_B64}" -gt 100 ]; then
    echo "✅ Encontrado campo kubeconfig en Secret bootstrap-hub-kubeconfig"
    echo "   Tamaño del base64: ${#KUBECONFIG_B64} caracteres"
    echo ""
    
    # Decodificar base64
    KUBECONFIG=$(echo "${KUBECONFIG_B64}" | base64 -d 2>/dev/null)
    
    if [ -n "${KUBECONFIG}" ] && echo "${KUBECONFIG}" | grep -q "apiVersion: v1"; then
        echo "✅ Kubeconfig decodificado exitosamente"
        echo ""
        echo "📋 Primeras líneas del kubeconfig:"
        echo "${KUBECONFIG}" | head -10
        echo ""
        
        # Guardar en archivo
        echo "${KUBECONFIG}" > /tmp/kubeconfig-${CLUSTER_NAME}
        chmod 600 /tmp/kubeconfig-${CLUSTER_NAME}
        echo "✅ Kubeconfig guardado en: /tmp/kubeconfig-${CLUSTER_NAME}"
        exit 0
    else
        echo "⚠️  El kubeconfig decodificado no parece válido"
        echo "   Primeros caracteres: ${KUBECONFIG:0:50}..."
    fi
else
    echo "⚠️  No se pudo extraer el campo kubeconfig del Secret bootstrap-hub-kubeconfig"
fi

# Método 2: Intentar con yq si está disponible
if command -v yq >/dev/null 2>&1; then
    echo ""
    echo "🔍 Intentando con yq..."
    KUBECONFIG_B64_YQ=$(echo "${IMPORT_YAML}" | yq -s '.[] | select(.kind=="Secret" and .metadata.name=="bootstrap-hub-kubeconfig") | .data.kubeconfig' | head -1)
    
    if [ -n "${KUBECONFIG_B64_YQ}" ]; then
        KUBECONFIG=$(echo "${KUBECONFIG_B64_YQ}" | base64 -d 2>/dev/null)
        if [ -n "${KUBECONFIG}" ] && echo "${KUBECONFIG}" | grep -q "apiVersion: v1"; then
            echo "✅ Kubeconfig extraído usando yq"
            echo "${KUBECONFIG}" > /tmp/kubeconfig-${CLUSTER_NAME}
            chmod 600 /tmp/kubeconfig-${CLUSTER_NAME}
            echo "✅ Kubeconfig guardado en: /tmp/kubeconfig-${CLUSTER_NAME}"
            exit 0
        fi
    fi
fi

# Si ningún método funcionó, mostrar el contenido completo para análisis
echo "⚠️  No se pudo extraer automáticamente. Mostrando contenido completo:"
echo "----------------------------------------"
echo "${IMPORT_YAML}"
echo "----------------------------------------"
echo ""
echo "💡 Revisa la estructura y ajusta el script según sea necesario"

