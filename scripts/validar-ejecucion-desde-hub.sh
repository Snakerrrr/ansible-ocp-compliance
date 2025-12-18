#!/bin/bash
# Script de validación para ejecutar el playbook desde el HUB
# Verifica que todos los componentes funcionen correctamente cuando se ejecuta desde el cluster HUB

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=========================================="
echo "Validación: Ejecución desde HUB Cluster"
echo "=========================================="
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir resultados
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 1. Verificar contexto actual de oc
echo "1. Verificando contexto de OpenShift..."
CURRENT_CONTEXT=$(oc config current-context 2>/dev/null || echo "")
if [ -z "$CURRENT_CONTEXT" ]; then
    print_result 1 "No hay contexto de OpenShift configurado"
    echo "   Ejecuta: oc login <hub-cluster-url>"
    exit 1
else
    print_result 0 "Contexto actual: $CURRENT_CONTEXT"
fi
echo ""

# 2. Verificar que estamos en el HUB (buscar recursos de ACM)
echo "2. Verificando que estamos en el HUB cluster..."
if oc get managedclusters &>/dev/null; then
    print_result 0 "Recursos de ACM detectados (estamos en el HUB)"
    HUB_CLUSTER=$(oc config view -o jsonpath='{.contexts[?(@.name=="'$CURRENT_CONTEXT'")].context.cluster}' 2>/dev/null || echo "unknown")
    echo "   Cluster HUB: $HUB_CONTEXT"
else
    print_result 1 "No se detectaron recursos de ACM. ¿Estás en el HUB?"
    print_warning "Si estás en cluster-acs, este script debe ejecutarse desde el HUB"
fi
echo ""

# 3. Verificar que el cluster-acs está registrado y tiene el label correcto
echo "3. Verificando cluster-acs en ACM..."
if oc get managedcluster cluster-acs &>/dev/null; then
    print_result 0 "cluster-acs está registrado en ACM"
    
    # Verificar label
    ACS_LABEL=$(oc get managedcluster cluster-acs -o jsonpath='{.metadata.labels.environment}' 2>/dev/null || echo "")
    if [ "$ACS_LABEL" == "cluster-acs" ]; then
        print_result 0 "Label 'environment=cluster-acs' está configurado correctamente"
    else
        print_result 1 "Label 'environment=cluster-acs' NO está configurado"
        echo "   Label actual: environment=$ACS_LABEL"
        print_warning "Configurar con: oc label managedcluster cluster-acs environment=cluster-acs"
    fi
    
    # Verificar estado del cluster
    ACS_STATUS=$(oc get managedcluster cluster-acs -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "Unknown")
    if [ "$ACS_STATUS" == "True" ]; then
        print_result 0 "cluster-acs está disponible"
    else
        print_warning "cluster-acs puede no estar disponible (status: $ACS_STATUS)"
    fi
else
    print_result 1 "cluster-acs NO está registrado en ACM"
    print_warning "Registra el cluster con ACM antes de continuar"
fi
echo ""

# 4. Verificar políticas existentes en el namespace policies
echo "4. Verificando políticas de compliance en el HUB..."
if oc get policies -n policies &>/dev/null; then
    POLICY_COUNT=$(oc get policies -n policies --no-headers 2>/dev/null | wc -l)
    print_result 0 "Se encontraron $POLICY_COUNT política(s) en namespace 'policies'"
    
    # Verificar políticas específicas
    if oc get policy install-compliance-operator -n policies &>/dev/null; then
        print_result 0 "Política 'install-compliance-operator' existe"
    else
        print_warning "Política 'install-compliance-operator' no existe aún"
    fi
    
    if oc get policy run-cis-scan -n policies &>/dev/null; then
        print_result 0 "Política 'run-cis-scan' existe"
    else
        print_warning "Política 'run-cis-scan' no existe aún"
    fi
    
    if oc get policy run-pci-scan -n policies &>/dev/null; then
        print_result 0 "Política 'run-pci-scan' existe"
    else
        print_warning "Política 'run-pci-scan' no existe aún"
    fi
else
    print_warning "Namespace 'policies' no existe o no hay políticas aún"
    print_warning "Esto es normal si aún no has ejecutado el playbook GitOps"
fi
echo ""

# 5. Verificar PlacementRules y PlacementBindings
echo "5. Verificando PlacementRules..."
if oc get placementrule -n policies &>/dev/null; then
    PLACEMENT_COUNT=$(oc get placementrule -n policies --no-headers 2>/dev/null | wc -l)
    print_result 0 "Se encontraron $PLACEMENT_COUNT PlacementRule(s)"
    
    # Verificar que las PlacementRules apuntan al cluster correcto
    oc get placementrule -n policies -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.clusterSelector.matchLabels.environment}{"\n"}{end}' 2>/dev/null | while read name label; do
        if [ "$label" == "cluster-acs" ]; then
            print_result 0 "PlacementRule '$name' apunta a cluster-acs"
        else
            print_warning "PlacementRule '$name' apunta a: $label"
        fi
    done
else
    print_warning "No se encontraron PlacementRules. Se crearán automáticamente por PolicyGenerator"
fi
echo ""

# 6. Verificar acceso a PVCs del cluster-acs (CRÍTICO)
echo "6. Verificando acceso a PVCs del cluster-acs..."
echo "   NOTA: Para exportar HTML desde el HUB, necesitas acceso a los PVCs del cluster-acs"
echo ""

# Opción 1: Usar oc con contexto del cluster-acs
if oc get pvc -n openshift-compliance --context=cluster-acs &>/dev/null 2>&1; then
    print_result 0 "Acceso a PVCs del cluster-acs mediante contexto 'cluster-acs'"
    PVC_COUNT=$(oc get pvc -n openshift-compliance --context=cluster-acs --no-headers 2>/dev/null | wc -l)
    echo "   Se encontraron $PVC_COUNT PVC(s) en openshift-compliance"
    
    # Verificar PVCs específicos
    CIS_PVCS=$(oc get pvc -n openshift-compliance --context=cluster-acs --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null | grep -c "^ocp4-cis" || echo "0")
    PCI_PVCS=$(oc get pvc -n openshift-compliance --context=cluster-acs --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null | grep -c "^ocp4-pci-dss" || echo "0")
    
    if [ "$CIS_PVCS" -gt 0 ]; then
        print_result 0 "Se encontraron $CIS_PVCS PVC(s) de CIS"
    else
        print_warning "No se encontraron PVCs de CIS aún"
    fi
    
    if [ "$PCI_PVCS" -gt 0 ]; then
        print_result 0 "Se encontraron $PCI_PVCS PVC(s) de PCI"
    else
        print_warning "No se encontraron PVCs de PCI aún"
    fi
else
    print_warning "No se puede acceder a PVCs usando contexto 'cluster-acs'"
    echo ""
    echo "   Opciones para acceder a PVCs del cluster-acs desde el HUB:"
    echo "   1. Configurar contexto de cluster-acs:"
    echo "      oc config set-context cluster-acs --cluster=<cluster-url> --user=<user> --namespace=openshift-compliance"
    echo ""
    echo "   2. O usar oc con --context directamente en el playbook"
    echo ""
    echo "   3. O modificar el rol compliance_export_html para usar el contexto correcto"
fi
echo ""

# 7. Verificar herramientas necesarias
echo "7. Verificando herramientas necesarias..."
TOOLS_OK=true

if command -v ansible-playbook &>/dev/null; then
    print_result 0 "ansible-playbook está disponible"
else
    print_result 1 "ansible-playbook NO está disponible"
    TOOLS_OK=false
fi

if command -v oc &>/dev/null; then
    print_result 0 "oc (OpenShift CLI) está disponible"
else
    print_result 1 "oc NO está disponible"
    TOOLS_OK=false
fi

if command -v oscap &>/dev/null; then
    print_result 0 "oscap está disponible"
else
    print_warning "oscap NO está disponible (necesario para export HTML)"
    echo "   Instalar con: sudo apt-get install openscap-scanner"
fi

if command -v git &>/dev/null; then
    print_result 0 "git está disponible"
else
    print_result 1 "git NO está disponible"
    TOOLS_OK=false
fi

if [ "$TOOLS_OK" = false ]; then
    echo ""
    print_warning "Algunas herramientas faltan. Instálalas antes de ejecutar el playbook."
fi
echo ""

# 8. Resumen y recomendaciones
echo "=========================================="
echo "Resumen de Validación"
echo "=========================================="
echo ""
echo "✅ Checklist para ejecutar desde HUB:"
echo ""
echo "  [ ] Estás logueado al HUB cluster"
echo "  [ ] cluster-acs está registrado en ACM"
echo "  [ ] cluster-acs tiene label 'environment=cluster-acs'"
echo "  [ ] Tienes acceso a PVCs del cluster-acs (contexto o --context)"
echo "  [ ] Herramientas instaladas (ansible, oc, oscap, git)"
echo ""
echo "📝 Notas importantes:"
echo ""
echo "  1. GitOps (do_gitops=true):"
echo "     - Se ejecuta desde cualquier lugar (solo necesita GitHub)"
echo "     - Las políticas se aplican al cluster-acs vía ACM/Placement"
echo ""
echo "  2. Export HTML (do_export_html=true):"
echo "     - REQUIERE acceso a los PVCs del cluster-acs"
echo "     - Opciones:"
echo "       a) Usar contexto: oc config use-context cluster-acs"
echo "       b) Modificar rol para usar: oc get pvc --context=cluster-acs"
echo "       c) Ejecutar desde un bastión con acceso a ambos clusters"
echo ""
echo "  3. Label Selector:"
echo "     - Configurado en: roles/toggle_policies/templates/policy-generator-config.yaml.j2"
echo "     - Busca: environment=cluster-acs"
echo "     - Asegúrate que el cluster-acs tenga este label"
echo ""
echo "=========================================="
echo ""

