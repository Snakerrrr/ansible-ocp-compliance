# Script de validación para ejecutar el playbook desde el HUB
# Verifica que el label selector y el contexto de cluster funcionen correctamente

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Validación: Ejecución desde HUB" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar que estamos en el HUB
Write-Host "1. Verificando contexto actual..." -ForegroundColor Yellow
try {
    $currentContext = oc config current-context 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ No hay contexto de OpenShift configurado" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Contexto actual: $currentContext" -ForegroundColor Green
} catch {
    Write-Host "❌ Error al obtener contexto: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Verificar que podemos acceder al HUB
Write-Host "2. Verificando acceso al HUB (ACM)..." -ForegroundColor Yellow
$hubCheck = oc get managedclusters 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Acceso al HUB confirmado" -ForegroundColor Green
} else {
    Write-Host "❌ No se puede acceder al HUB. ¿Estás logueado correctamente?" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Listar managed clusters disponibles
Write-Host "3. Clusters gestionados disponibles:" -ForegroundColor Yellow
$managedClusters = oc get managedclusters -o custom-columns=NAME:.metadata.name,LABELS:.metadata.labels --no-headers 2>&1
if ($LASTEXITCODE -eq 0) {
    $managedClusters | ForEach-Object {
        Write-Host "   $_" -ForegroundColor Gray
    }
} else {
    Write-Host "   No se pudieron listar los clusters" -ForegroundColor Yellow
}
Write-Host ""

# Verificar label selector configurado
Write-Host "4. Verificando label selector configurado..." -ForegroundColor Yellow
$placementLabelKey = if ($env:PLACEMENT_LABEL_KEY) { $env:PLACEMENT_LABEL_KEY } else { "environment" }
$placementLabelValue = if ($env:PLACEMENT_LABEL_VALUE) { $env:PLACEMENT_LABEL_VALUE } else { "cluster-acs" }

Write-Host "   Label Key: $placementLabelKey" -ForegroundColor Cyan
Write-Host "   Label Value: $placementLabelValue" -ForegroundColor Cyan
Write-Host ""

# Verificar que el cluster objetivo tiene el label
Write-Host "5. Verificando que el cluster objetivo tiene el label..." -ForegroundColor Yellow
$labelCheck = oc get managedcluster $placementLabelValue -o jsonpath='{.metadata.labels}' 2>&1
if ($LASTEXITCODE -eq 0 -and $labelCheck -match $placementLabelKey) {
    Write-Host "✅ Cluster $placementLabelValue tiene el label $placementLabelKey" -ForegroundColor Green
} else {
    Write-Host "⚠️  Cluster $placementLabelValue no tiene el label $placementLabelKey" -ForegroundColor Yellow
    Write-Host "   Puedes agregarlo con:" -ForegroundColor Gray
    Write-Host "   oc label managedcluster $placementLabelValue $placementLabelKey=$placementLabelValue" -ForegroundColor Gray
}
Write-Host ""

# Verificar políticas ACM existentes
Write-Host "6. Verificando políticas ACM en el HUB..." -ForegroundColor Yellow
$policies = oc get policies -n policies --no-headers 2>&1
if ($LASTEXITCODE -eq 0) {
    $policyCount = ($policies | Measure-Object -Line).Lines
    Write-Host "✅ Encontradas $policyCount política(s) en el namespace 'policies'" -ForegroundColor Green
    Write-Host ""
    Write-Host "   Políticas relevantes:" -ForegroundColor Cyan
    $policies | Select-String -Pattern "(compliance|cis|pci)" | Select-Object -First 5 | ForEach-Object {
        Write-Host "   - $_" -ForegroundColor Gray
    }
} else {
    Write-Host "⚠️  No se encontraron políticas en el namespace 'policies'" -ForegroundColor Yellow
    Write-Host "   Esto es normal si es la primera ejecución" -ForegroundColor Gray
}
Write-Host ""

# Verificar contexto del cluster objetivo (si se especifica)
$targetClusterContext = if ($env:TARGET_CLUSTER_CONTEXT) { $env:TARGET_CLUSTER_CONTEXT } else { "" }
if ($targetClusterContext) {
    Write-Host "7. Verificando contexto del cluster objetivo: $targetClusterContext" -ForegroundColor Yellow
    $pvcCheck = oc get pvc -n openshift-compliance --context=$targetClusterContext 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Acceso al cluster $targetClusterContext confirmado" -ForegroundColor Green
        
        # Contar PVCs en el cluster objetivo
        $pvcList = oc get pvc -n openshift-compliance --context=$targetClusterContext --no-headers 2>&1
        if ($LASTEXITCODE -eq 0) {
            $pvcCount = ($pvcList | Measure-Object -Line).Lines
            Write-Host "   PVCs encontrados en openshift-compliance: $pvcCount" -ForegroundColor Cyan
        }
    } else {
        Write-Host "❌ No se puede acceder al cluster $targetClusterContext" -ForegroundColor Red
        Write-Host "   Verifica que el contexto existe: oc config get-contexts" -ForegroundColor Gray
    }
    Write-Host ""
} else {
    Write-Host "7. No se especificó target_cluster_context" -ForegroundColor Yellow
    Write-Host "   Se usará el contexto actual para exportar HTML" -ForegroundColor Gray
    Write-Host ""
}

# Resumen y recomendaciones
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "RESUMEN" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Validaciones completadas" -ForegroundColor Green
Write-Host ""
Write-Host "Para ejecutar el playbook desde el HUB:" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANTE: Exportar ANSIBLE_ROLES_PATH antes de ejecutar:" -ForegroundColor Yellow
Write-Host "   `$env:ANSIBLE_ROLES_PATH = `"`$(Get-Location)\roles`"" -ForegroundColor Gray
Write-Host ""
Write-Host "1. Solo GitOps (toggle policies):" -ForegroundColor Yellow
Write-Host "   `$env:ANSIBLE_ROLES_PATH = `"`$(Get-Location)\roles`"" -ForegroundColor Gray
Write-Host "   ansible-playbook playbooks/compliance-pipeline.yml \`" -ForegroundColor Gray
Write-Host "     -i inventories/localhost.yml \`" -ForegroundColor Gray
Write-Host "     -e `"github_token=XXX do_gitops=true do_export_html=false \`" -ForegroundColor Gray
Write-Host "         placement_label_key=$placementLabelKey \`" -ForegroundColor Gray
Write-Host "         placement_label_value=$placementLabelValue`"" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Solo export HTML (desde HUB, apuntando a cluster-acs):" -ForegroundColor Yellow
$targetContext = if ($targetClusterContext) { $targetClusterContext } else { "cluster-acs" }
Write-Host "   `$env:ANSIBLE_ROLES_PATH = `"`$(Get-Location)\roles`"" -ForegroundColor Gray
Write-Host "   ansible-playbook playbooks/compliance-pipeline.yml \`" -ForegroundColor Gray
Write-Host "     -i inventories/localhost.yml \`" -ForegroundColor Gray
Write-Host "     -e `"do_gitops=false do_export_html=true \`" -ForegroundColor Gray
Write-Host "         target_cluster_context=$targetContext`"" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Pipeline completo (GitOps + Export HTML):" -ForegroundColor Yellow
Write-Host "   `$env:ANSIBLE_ROLES_PATH = `"`$(Get-Location)\roles`"" -ForegroundColor Gray
Write-Host "   ansible-playbook playbooks/compliance-pipeline.yml \`" -ForegroundColor Gray
Write-Host "     -i inventories/localhost.yml \`" -ForegroundColor Gray
Write-Host "     -e `"github_token=XXX do_gitops=true do_export_html=true \`" -ForegroundColor Gray
Write-Host "         placement_label_key=$placementLabelKey \`" -ForegroundColor Gray
Write-Host "         placement_label_value=$placementLabelValue \`" -ForegroundColor Gray
Write-Host "         target_cluster_context=$targetContext`"" -ForegroundColor Gray
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan

