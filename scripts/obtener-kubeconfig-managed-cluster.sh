#!/bin/bash
# Script para obtener el kubeconfig del managed cluster desde el Hub

set -e

CLUSTER_NAME="${1:-cluster-acs}"
KUBECONFIG_PATH="/tmp/kubeconfig-${CLUSTER_NAME}"

echo "=========================================="
echo "Obteniendo kubeconfig del managed cluster"
echo "=========================================="
echo ""
echo "Cluster: ${CLUSTER_NAME}"
echo "Destino: ${KUBECONFIG_PATH}"
echo ""

# Verificar que estamos en el Hub
echo "1. Verificando que estamos en el Hub..."
if ! oc get managedcluster ${CLUSTER_NAME} &>/dev/null; then
    echo "❌ Error: No se puede acceder al Hub o el managed cluster '${CLUSTER_NAME}' no existe"
    echo ""
    echo "Clusters disponibles:"
    oc get managedclusters --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null || echo "No se pudieron listar"
    exit 1
fi
echo "✅ Managed cluster '${CLUSTER_NAME}' encontrado"
echo ""

# Intentar obtener desde diferentes ubicaciones
echo "2. Intentando obtener kubeconfig..."

# Opción 1: Secret admin-kubeconfig en namespace del cluster
echo "   Intentando desde secret admin-kubeconfig..."
if oc get secret -n ${CLUSTER_NAME} admin-kubeconfig &>/dev/null; then
    echo "   ✅ Secret encontrado en namespace '${CLUSTER_NAME}'"
    oc get secret -n ${CLUSTER_NAME} admin-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d > ${KUBECONFIG_PATH}
    chmod 600 ${KUBECONFIG_PATH}
    echo "   ✅ Kubeconfig guardado en: ${KUBECONFIG_PATH}"
    exit 0
fi

# Opción 2: Secret en namespace con sufijo -cluster
echo "   Intentando desde namespace '${CLUSTER_NAME}-cluster'..."
if oc get secret -n ${CLUSTER_NAME}-cluster admin-kubeconfig &>/dev/null; then
    echo "   ✅ Secret encontrado en namespace '${CLUSTER_NAME}-cluster'"
    oc get secret -n ${CLUSTER_NAME}-cluster admin-kubeconfig -o jsonpath='{.data.kubeconfig}' | base64 -d > ${KUBECONFIG_PATH}
    chmod 600 ${KUBECONFIG_PATH}
    echo "   ✅ Kubeconfig guardado en: ${KUBECONFIG_PATH}"
    exit 0
fi

# Opción 3: Obtener URL del API server y crear kubeconfig temporal
echo "   Intentando crear kubeconfig usando API URL del managed cluster..."
API_URL=$(oc get managedcluster ${CLUSTER_NAME} -o jsonpath='{.status.clusterClaims[?(@.name=="platform.open-cluster-management.io/apiurl")].value}' 2>/dev/null || \
          oc get managedcluster ${CLUSTER_NAME} -o jsonpath='{.spec.managedClusterClientConfigs[0].url}' 2>/dev/null || \
          echo "")

if [ -n "${API_URL}" ] && [ "${API_URL}" != "" ]; then
    echo "   ✅ API URL obtenida: ${API_URL}"
    TOKEN=$(oc whoami -t)
    
    if [ -n "${TOKEN}" ]; then
        cat > ${KUBECONFIG_PATH} <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: ${API_URL}
    insecure-skip-tls-verify: true
  name: ${CLUSTER_NAME}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: ${CLUSTER_NAME}-admin
  name: ${CLUSTER_NAME}
current-context: ${CLUSTER_NAME}
users:
- name: ${CLUSTER_NAME}-admin
  user:
    token: ${TOKEN}
EOF
        chmod 600 ${KUBECONFIG_PATH}
        echo "   ✅ Kubeconfig temporal creado en: ${KUBECONFIG_PATH}"
        echo "   ⚠️  Nota: Este kubeconfig usa el token del Hub. Puede que no tenga permisos."
        exit 0
    fi
fi

# Si llegamos aquí, no se pudo obtener
echo ""
echo "❌ No se pudo obtener el kubeconfig automáticamente"
echo ""
echo "Opciones manuales:"
echo ""
echo "1. Si tienes acceso directo al managed cluster ${CLUSTER_NAME}:"
echo "   oc login <api-server-url-del-managed-cluster>"
echo "   oc config view --minify --raw > ${KUBECONFIG_PATH}"
echo ""
echo "2. Buscar secret manualmente:"
echo "   oc get secrets -A | grep kubeconfig"
echo "   oc get secret <nombre-del-secret> -n <namespace> -o jsonpath='{.data.kubeconfig}' | base64 -d > ${KUBECONFIG_PATH}"
echo ""
echo "3. Si el secret hub-kubeconfig-secret existe en el managed cluster:"
echo "   (Necesitas estar logueado al managed cluster)"
echo "   oc get secret hub-kubeconfig-secret -n <namespace> -o jsonpath='{.data.kubeconfig}' | base64 -d > ${KUBECONFIG_PATH}"
echo ""
exit 1

