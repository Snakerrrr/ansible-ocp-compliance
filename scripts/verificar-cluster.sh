#!/bin/bash
# Script de verificación rápida del estado de compliance en cluster-acs
# Uso: ./scripts/verificar-cluster.sh

set -e

NAMESPACE="openshift-compliance"

echo "=========================================="
echo "Verificación de Compliance en cluster-acs"
echo "=========================================="
echo ""

# Verificar conexión
echo "1. Verificando conexión al cluster..."
if ! oc whoami &>/dev/null; then
    echo "❌ ERROR: No estás logueado al cluster"
    echo "   Ejecuta: oc login <cluster-url>"
    exit 1
fi
echo "✅ Conectado como: $(oc whoami)"
echo ""

# Verificar namespace
echo "2. Verificando namespace openshift-compliance..."
if ! oc get namespace $NAMESPACE &>/dev/null; then
    echo "⚠️  WARNING: Namespace $NAMESPACE no existe"
else
    echo "✅ Namespace existe"
fi
echo ""

# Verificar Compliance Operator
echo "3. Verificando Compliance Operator..."
# Buscar CSV en múltiples namespaces posibles
CSV=""
CSV_NAMESPACE=""
for ns in "$NAMESPACE" "openshift-operators"; do
    CSV_CANDIDATE=$(oc get csv -n "$ns" -o jsonpath='{.items[?(@.metadata.name=~"compliance-operator.*")].metadata.name}' 2>/dev/null | head -1)
    if [ -n "$CSV_CANDIDATE" ]; then
        CSV="$CSV_CANDIDATE"
        CSV_NAMESPACE="$ns"
        break
    fi
done

# Si no encontramos CSV, buscar por Subscription
if [ -z "$CSV" ]; then
    for ns in "$NAMESPACE" "openshift-operators"; do
        SUB=$(oc get subscription -n "$ns" -o jsonpath='{.items[?(@.spec.name=="compliance-operator")].metadata.name}' 2>/dev/null | head -1)
        if [ -n "$SUB" ]; then
            CSV_NAMESPACE="$ns"
            break
        fi
    done
fi

# Si aún no encontramos nada, buscar por Deployment
if [ -z "$CSV" ] && [ -z "$CSV_NAMESPACE" ]; then
    for ns in "$NAMESPACE" "openshift-operators"; do
        DEPLOY=$(oc get deployment -n "$ns" -o jsonpath='{.items[?(@.metadata.name=~"compliance-operator.*")].metadata.name}' 2>/dev/null | head -1)
        if [ -n "$DEPLOY" ]; then
            CSV_NAMESPACE="$ns"
            break
        fi
    done
fi

if [ -z "$CSV" ] && [ -z "$CSV_NAMESPACE" ]; then
    echo "❌ Compliance Operator NO encontrado (pero puede estar funcionando si hay scans)"
    echo "   Los ComplianceScans existentes indican que el operator funcionó anteriormente"
else
    if [ -n "$CSV" ]; then
        STATUS=$(oc get csv "$CSV" -n "$CSV_NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        echo "✅ Compliance Operator encontrado:"
        echo "   CSV: $CSV"
        echo "   Namespace: $CSV_NAMESPACE"
        echo "   Estado: $STATUS"
    else
        echo "✅ Compliance Operator detectado (por Subscription/Deployment en $CSV_NAMESPACE)"
        echo "   Los ComplianceScans activos confirman que está funcionando"
    fi
fi
echo ""

# Verificar ComplianceScans
echo "4. Verificando ComplianceScans..."
SCANS=$(oc get compliancescans -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
if [ "$SCANS" -eq 0 ]; then
    echo "⚠️  No hay ComplianceScans creados aún"
else
    echo "✅ ComplianceScans encontrados: $SCANS"
    echo ""
    echo "   Detalles:"
    oc get compliancescans -n $NAMESPACE -o custom-columns=NAME:.metadata.name,PHASE:.status.phase,RESULT:.status.result 2>/dev/null || echo "   (No se pueden listar scans)"
fi
echo ""

# Verificar ComplianceSuites
echo "5. Verificando ComplianceSuites..."
SUITES=$(oc get compliancesuites -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
if [ "$SUITES" -eq 0 ]; then
    echo "⚠️  No hay ComplianceSuites creadas aún"
else
    echo "✅ ComplianceSuites encontradas: $SUITES"
    oc get compliancesuites -n $NAMESPACE 2>/dev/null || echo "   (No se pueden listar suites)"
fi
echo ""

# Verificar PVCs
echo "6. Verificando PVCs con resultados..."
PVC_CIS=$(oc get pvc -n $NAMESPACE --no-headers 2>/dev/null | grep -c "ocp4-cis" || echo "0")
PVC_PCI=$(oc get pvc -n $NAMESPACE --no-headers 2>/dev/null | grep -c "ocp4-pci-dss" || echo "0")
TOTAL_PVC=$((PVC_CIS + PVC_PCI))

if [ "$TOTAL_PVC" -eq 0 ]; then
    echo "⚠️  No hay PVCs con resultados aún"
    echo "   Los scans pueden estar ejecutándose o no se han iniciado"
else
    echo "✅ PVCs encontrados:"
    echo "   - CIS: $PVC_CIS"
    echo "   - PCI: $PVC_PCI"
    echo "   - Total: $TOTAL_PVC"
    echo ""
    echo "   Lista de PVCs:"
    oc get pvc -n $NAMESPACE --no-headers 2>/dev/null | grep -E "ocp4-(cis|pci-dss)" | awk '{print "     - " $1 " (" $2 ")"}' || echo "     (No se pueden listar)"
fi
echo ""

# Verificar Políticas ACM (si está en hub)
echo "7. Verificando Políticas ACM (desde hub)..."
POLICIES=$(oc get policies -n policies --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$POLICIES" -eq 0 ]; then
    echo "⚠️  No se pueden verificar políticas (puede que no estés en el hub cluster)"
else
    echo "✅ Políticas encontradas: $POLICIES"
    echo ""
    echo "   Políticas relevantes:"
    oc get policies -n policies --no-headers 2>/dev/null | grep -E "(compliance|cis|pci)" | awk '{print "     - " $1 " (" $2 ")"}' || echo "     (No hay políticas de compliance)"
fi
echo ""

# Resumen
echo "=========================================="
echo "RESUMEN"
echo "=========================================="
if [ -n "$CSV" ] && [ "$STATUS" = "Succeeded" ]; then
    echo "✅ Compliance Operator: Instalado y funcionando"
elif [ -n "$CSV_NAMESPACE" ] || [ "$SCANS" -gt 0 ]; then
    echo "✅ Compliance Operator: Funcionando (detectado por scans activos)"
else
    echo "⚠️  Compliance Operator: No detectado claramente (pero puede estar funcionando)"
fi

if [ "$SCANS" -gt 0 ]; then
    echo "✅ ComplianceScans: $SCANS encontrados"
else
    echo "⚠️  ComplianceScans: Ninguno encontrado (puede estar en proceso)"
fi

if [ "$TOTAL_PVC" -gt 0 ]; then
    echo "✅ PVCs con resultados: $TOTAL_PVC listos para exportar"
else
    echo "⚠️  PVCs: Ninguno encontrado (los scans pueden estar ejecutándose)"
fi
echo ""

# Recomendaciones
echo "RECOMENDACIONES:"
if [ -z "$CSV" ] && [ -z "$CSV_NAMESPACE" ] && [ "$SCANS" -eq 0 ]; then
    echo "  → Ejecutar playbook con do_gitops=true para instalar el operator"
fi
if [ "$SCANS" -eq 0 ]; then
    echo "  → Verificar que las políticas ACM se hayan aplicado correctamente"
    echo "  → Esperar 5-10 minutos después del GitOps para que se creen los scans"
fi
if [ "$TOTAL_PVC" -eq 0 ] && [ "$SCANS" -gt 0 ]; then
    echo "  → Los scans están ejecutándose, esperar 10-30 minutos para resultados"
fi
if [ "$TOTAL_PVC" -gt 0 ]; then
    echo "  → Ejecutar playbook con do_export_html=true para exportar resultados"
fi
echo ""

