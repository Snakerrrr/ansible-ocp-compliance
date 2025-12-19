#!/bin/bash
# Script para crear/actualizar un secret en el Hub que contiene el kubeconfig del managed cluster
# Esto es más seguro que mantener kubeconfigs en archivos locales

set -e

CLUSTER_NAME="${1}"
KUBECONFIG_PATH="${2}"
SECRET_NAMESPACE="${3:-${CLUSTER_NAME}}"
SECRET_NAME="managed-cluster-kubeconfig-${CLUSTER_NAME}"

if [ -z "${CLUSTER_NAME}" ]; then
    echo "❌ Error: Debes especificar el nombre del managed cluster"
    echo ""
    echo "Uso:"
    echo "  $0 <cluster-name> [kubeconfig-path] [namespace]"
    echo ""
    echo "Ejemplos:"
    echo "  # Crear secret desde archivo existente"
    echo "  $0 cluster-acs /tmp/kubeconfig-cluster-acs"
    echo ""
    echo "  # Crear secret interactivamente (solicitará kubeconfig)"
    echo "  $0 cluster-acs"
    echo ""
    echo "  # Especificar namespace personalizado"
    echo "  $0 cluster-acs /tmp/kubeconfig-cluster-acs compliance-kubeconfigs"
    exit 1
fi

echo "=========================================="
echo "Creando/Actualizando Secret de Kubeconfig"
echo "=========================================="
echo ""
echo "Cluster: ${CLUSTER_NAME}"
echo "Secret: ${SECRET_NAME}"
echo "Namespace: ${SECRET_NAMESPACE}"
echo ""

# Verificar que estamos en el Hub
if ! oc get managedcluster ${CLUSTER_NAME} &>/dev/null; then
    echo "⚠️  Advertencia: No se encontró el managed cluster '${CLUSTER_NAME}' en el Hub"
    echo "   Continuando de todas formas..."
    echo ""
fi

# Obtener kubeconfig
if [ -n "${KUBECONFIG_PATH}" ] && [ -f "${KUBECONFIG_PATH}" ]; then
    echo "📁 Leyendo kubeconfig desde: ${KUBECONFIG_PATH}"
    KUBECONFIG_CONTENT=$(cat "${KUBECONFIG_PATH}")
elif [ -f "/tmp/kubeconfig-${CLUSTER_NAME}" ]; then
    echo "📁 Leyendo kubeconfig desde ubicación por defecto: /tmp/kubeconfig-${CLUSTER_NAME}"
    KUBECONFIG_CONTENT=$(cat "/tmp/kubeconfig-${CLUSTER_NAME}")
else
    echo "❌ No se encontró kubeconfig en ninguna ubicación"
    echo ""
    echo "Opciones:"
    echo "  1. Especificar ruta: $0 ${CLUSTER_NAME} /ruta/al/kubeconfig"
    echo "  2. Guardar en ubicación por defecto: cp /ruta/al/kubeconfig /tmp/kubeconfig-${CLUSTER_NAME}"
    echo "  3. Obtener desde managed cluster:"
    echo "     oc login <api-server-url>"
    echo "     oc config view --minify --raw > /tmp/kubeconfig-${CLUSTER_NAME}"
    exit 1
fi

# Verificar que el contenido no está vacío
if [ -z "${KUBECONFIG_CONTENT}" ] || [ ${#KUBECONFIG_CONTENT} -lt 100 ]; then
    echo "❌ Error: El kubeconfig está vacío o inválido"
    exit 1
fi

# Verificar validez básica del kubeconfig
if ! echo "${KUBECONFIG_CONTENT}" | grep -q "apiVersion: v1"; then
    echo "⚠️  Advertencia: El contenido no parece ser un kubeconfig válido (no contiene 'apiVersion: v1')"
    read -p "¿Continuar de todas formas? (s/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Crear namespace si no existe
if ! oc get namespace ${SECRET_NAMESPACE} &>/dev/null; then
    echo "📦 Creando namespace: ${SECRET_NAMESPACE}"
    oc create namespace ${SECRET_NAMESPACE}
    echo "✅ Namespace creado"
    echo ""
fi

# Crear o actualizar secret
echo "🔐 Creando/actualizando secret: ${SECRET_NAME}"
if oc get secret ${SECRET_NAME} -n ${SECRET_NAMESPACE} &>/dev/null; then
    echo "   Secret existente encontrado. Actualizando..."
    oc delete secret ${SECRET_NAME} -n ${SECRET_NAMESPACE} --ignore-not-found=true
fi

# Crear secret desde literal
echo "${KUBECONFIG_CONTENT}" | oc create secret generic ${SECRET_NAME} \
    -n ${SECRET_NAMESPACE} \
    --from-file=kubeconfig=/dev/stdin \
    --dry-run=client -o yaml | oc apply -f -

# Verificar que se creó correctamente
if oc get secret ${SECRET_NAME} -n ${SECRET_NAMESPACE} &>/dev/null; then
    echo "✅ Secret creado/actualizado exitosamente"
    echo ""
    echo "📋 Información del secret:"
    oc get secret ${SECRET_NAME} -n ${SECRET_NAMESPACE} -o jsonpath='{.metadata.name}' && echo ""
    echo "   Namespace: ${SECRET_NAMESPACE}"
    echo "   Tamaño: $(oc get secret ${SECRET_NAME} -n ${SECRET_NAMESPACE} -o jsonpath='{.data.kubeconfig}' | wc -c) bytes"
    echo ""
    echo "💡 El playbook ahora usará este secret automáticamente"
    echo ""
    echo "Para verificar:"
    echo "  oc get secret ${SECRET_NAME} -n ${SECRET_NAMESPACE}"
    echo ""
    echo "Para ver el contenido (base64):"
    echo "  oc get secret ${SECRET_NAME} -n ${SECRET_NAMESPACE} -o jsonpath='{.data.kubeconfig}' | base64 -d"
else
    echo "❌ Error: No se pudo crear el secret"
    exit 1
fi

