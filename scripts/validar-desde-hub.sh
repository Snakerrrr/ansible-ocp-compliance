#!/bin/bash
# Script de validación para ejecutar el playbook desde el HUB
# Verifica que el label selector y el contexto de cluster funcionen correctamente

set -e

echo "=========================================="
echo "Validación: Ejecución desde HUB"
echo "=========================================="
echo ""

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Verificar que estamos en el HUB
echo -e "${YELLOW}1. Verificando contexto actual...${NC}"
CURRENT_CONTEXT=$(oc config current-context 2>/dev/null || echo "")
if [ -z "$CURRENT_CONTEXT" ]; then
    echo -e "${RED}❌ No hay contexto de OpenShift configurado${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Contexto actual: ${CURRENT_CONTEXT}${NC}"
echo ""

# Verificar que podemos acceder al HUB
echo -e "${YELLOW}2. Verificando acceso al HUB (ACM)...${NC}"
if oc get managedclusters &>/dev/null; then
    echo -e "${GREEN}✅ Acceso al HUB confirmado${NC}"
else
    echo -e "${RED}❌ No se puede acceder al HUB. ¿Estás logueado correctamente?${NC}"
    exit 1
fi
echo ""

# Listar managed clusters disponibles
echo -e "${YELLOW}3. Clusters gestionados disponibles:${NC}"
oc get managedclusters -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels --no-headers | while read line; do
    echo "   $line"
done
echo ""

# Verificar label selector configurado
echo -e "${YELLOW}4. Verificando label selector configurado...${NC}"
PLACEMENT_LABEL_KEY="${PLACEMENT_LABEL_KEY:-environment}"
PLACEMENT_LABEL_VALUE="${PLACEMENT_LABEL_VALUE:-cluster-acs}"

echo "   Label Key: ${PLACEMENT_LABEL_KEY}"
echo "   Label Value: ${PLACEMENT_LABEL_VALUE}"
echo ""

# Verificar que el cluster objetivo tiene el label
echo -e "${YELLOW}5. Verificando que el cluster objetivo tiene el label...${NC}"
if oc get managedcluster "${PLACEMENT_LABEL_VALUE}" -o jsonpath='{.metadata.labels}' 2>/dev/null | grep -q "${PLACEMENT_LABEL_KEY}"; then
    echo -e "${GREEN}✅ Cluster ${PLACEMENT_LABEL_VALUE} tiene el label ${PLACEMENT_LABEL_KEY}${NC}"
else
    echo -e "${YELLOW}⚠️  Cluster ${PLACEMENT_LABEL_VALUE} no tiene el label ${PLACEMENT_LABEL_KEY}${NC}"
    echo "   Puedes agregarlo con:"
    echo "   oc label managedcluster ${PLACEMENT_LABEL_VALUE} ${PLACEMENT_LABEL_KEY}=${PLACEMENT_LABEL_VALUE}"
fi
echo ""

# Verificar políticas ACM existentes
echo -e "${YELLOW}6. Verificando políticas ACM en el HUB...${NC}"
POLICY_COUNT=$(oc get policies -n policies --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$POLICY_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Encontradas ${POLICY_COUNT} política(s) en el namespace 'policies'${NC}"
    echo ""
    echo "   Políticas relevantes:"
    oc get policies -n policies --no-headers | grep -E "(compliance|cis|pci)" | head -5 | while read line; do
        echo "   - $line"
    done
else
    echo -e "${YELLOW}⚠️  No se encontraron políticas en el namespace 'policies'${NC}"
    echo "   Esto es normal si es la primera ejecución"
fi
echo ""

# Verificar contexto del cluster objetivo (si se especifica)
TARGET_CLUSTER_CONTEXT="${TARGET_CLUSTER_CONTEXT:-}"
if [ -n "$TARGET_CLUSTER_CONTEXT" ]; then
    echo -e "${YELLOW}7. Verificando contexto del cluster objetivo: ${TARGET_CLUSTER_CONTEXT}${NC}"
    if oc get pvc -n openshift-compliance --context="${TARGET_CLUSTER_CONTEXT}" &>/dev/null; then
        echo -e "${GREEN}✅ Acceso al cluster ${TARGET_CLUSTER_CONTEXT} confirmado${NC}"
        
        # Contar PVCs en el cluster objetivo
        PVC_COUNT=$(oc get pvc -n openshift-compliance --context="${TARGET_CLUSTER_CONTEXT}" --no-headers 2>/dev/null | wc -l || echo "0")
        echo "   PVCs encontrados en openshift-compliance: ${PVC_COUNT}"
    else
        echo -e "${RED}❌ No se puede acceder al cluster ${TARGET_CLUSTER_CONTEXT}${NC}"
        echo "   Verifica que el contexto existe: oc config get-contexts"
    fi
    echo ""
else
    echo -e "${YELLOW}7. No se especificó target_cluster_context${NC}"
    echo "   Se usará el contexto actual para exportar HTML"
    echo ""
fi

# Resumen y recomendaciones
echo "=========================================="
echo -e "${GREEN}RESUMEN${NC}"
echo "=========================================="
echo ""
echo "✅ Validaciones completadas"
echo ""
echo "Para ejecutar el playbook desde el HUB:"
echo ""
echo "IMPORTANTE: Exportar ANSIBLE_ROLES_PATH antes de ejecutar:"
echo "   export ANSIBLE_ROLES_PATH=\$(pwd)/roles"
echo ""
echo "1. Solo GitOps (toggle policies):"
echo "   export ANSIBLE_ROLES_PATH=\$(pwd)/roles"
echo "   ansible-playbook playbooks/compliance-pipeline.yml \\"
echo "     -i inventories/localhost.yml \\"
echo "     -e \"github_token=XXX do_gitops=true do_export_html=false \\"
echo "         placement_label_key=${PLACEMENT_LABEL_KEY} \\"
echo "         placement_label_value=${PLACEMENT_LABEL_VALUE}\""
echo ""
echo "2. Solo export HTML (desde HUB, apuntando a cluster-acs):"
echo "   export ANSIBLE_ROLES_PATH=\$(pwd)/roles"
echo "   ansible-playbook playbooks/compliance-pipeline.yml \\"
echo "     -i inventories/localhost.yml \\"
echo "     -e \"do_gitops=false do_export_html=true \\"
echo "         target_cluster_context=${TARGET_CLUSTER_CONTEXT:-cluster-acs}\""
echo ""
echo "3. Pipeline completo (GitOps + Export HTML):"
echo "   export ANSIBLE_ROLES_PATH=\$(pwd)/roles"
echo "   ansible-playbook playbooks/compliance-pipeline.yml \\"
echo "     -i inventories/localhost.yml \\"
echo "     -e \"github_token=XXX do_gitops=true do_export_html=true \\"
echo "         placement_label_key=${PLACEMENT_LABEL_KEY} \\"
echo "         placement_label_value=${PLACEMENT_LABEL_VALUE} \\"
echo "         target_cluster_context=${TARGET_CLUSTER_CONTEXT:-cluster-acs}\""
echo ""
echo "=========================================="

