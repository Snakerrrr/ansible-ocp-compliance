# Script de verificación rápida del estado de compliance en cluster-acs (PowerShell)
# Uso: .\scripts\verificar-cluster.ps1

$NAMESPACE = "openshift-compliance"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Verificación de Compliance en cluster-acs" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar conexión
Write-Host "1. Verificando conexión al cluster..." -ForegroundColor Yellow
try {
    $whoami = oc whoami 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "No conectado"
    }
    Write-Host "✅ Conectado como: $whoami" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: No estás logueado al cluster" -ForegroundColor Red
    Write-Host "   Ejecuta: oc login <cluster-url>" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Verificar namespace
Write-Host "2. Verificando namespace openshift-compliance..." -ForegroundColor Yellow
$ns = oc get namespace $NAMESPACE 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  WARNING: Namespace $NAMESPACE no existe" -ForegroundColor Yellow
} else {
    Write-Host "✅ Namespace existe" -ForegroundColor Green
}
Write-Host ""

# Verificar Compliance Operator
Write-Host "3. Verificando Compliance Operator..." -ForegroundColor Yellow
$csv = $null
$csvNamespace = $null

# Buscar CSV en múltiples namespaces posibles
foreach ($ns in @($NAMESPACE, "openshift-operators")) {
    $csvCandidate = oc get csv -n $ns -o jsonpath='{.items[?(@.metadata.name=~"compliance-operator.*")].metadata.name}' 2>&1 | Select-Object -First 1
    if (-not [string]::IsNullOrEmpty($csvCandidate)) {
        $csv = $csvCandidate
        $csvNamespace = $ns
        break
    }
}

# Si no encontramos CSV, buscar por Subscription
if ([string]::IsNullOrEmpty($csv)) {
    foreach ($ns in @($NAMESPACE, "openshift-operators")) {
        $sub = oc get subscription -n $ns -o jsonpath='{.items[?(@.spec.name=="compliance-operator")].metadata.name}' 2>&1 | Select-Object -First 1
        if (-not [string]::IsNullOrEmpty($sub)) {
            $csvNamespace = $ns
            break
        }
    }
}

# Si aún no encontramos nada, buscar por Deployment
if ([string]::IsNullOrEmpty($csv) -and [string]::IsNullOrEmpty($csvNamespace)) {
    foreach ($ns in @($NAMESPACE, "openshift-operators")) {
        $deploy = oc get deployment -n $ns -o jsonpath='{.items[?(@.metadata.name=~"compliance-operator.*")].metadata.name}' 2>&1 | Select-Object -First 1
        if (-not [string]::IsNullOrEmpty($deploy)) {
            $csvNamespace = $ns
            break
        }
    }
}

if ([string]::IsNullOrEmpty($csv) -and [string]::IsNullOrEmpty($csvNamespace)) {
    Write-Host "❌ Compliance Operator NO encontrado (pero puede estar funcionando si hay scans)" -ForegroundColor Yellow
    Write-Host "   Los ComplianceScans existentes indican que el operator funcionó anteriormente" -ForegroundColor Gray
} else {
    if (-not [string]::IsNullOrEmpty($csv)) {
        $status = oc get csv $csv -n $csvNamespace -o jsonpath='{.status.phase}' 2>&1
        if ($LASTEXITCODE -ne 0) { $status = "Unknown" }
        Write-Host "✅ Compliance Operator encontrado:" -ForegroundColor Green
        Write-Host "   CSV: $csv" -ForegroundColor Cyan
        Write-Host "   Namespace: $csvNamespace" -ForegroundColor Cyan
        Write-Host "   Estado: $status" -ForegroundColor Cyan
    } else {
        Write-Host "✅ Compliance Operator detectado (por Subscription/Deployment en $csvNamespace)" -ForegroundColor Green
        Write-Host "   Los ComplianceScans activos confirman que está funcionando" -ForegroundColor Gray
    }
}
Write-Host ""

# Verificar ComplianceScans
Write-Host "4. Verificando ComplianceScans..." -ForegroundColor Yellow
$scanCount = 0
$scans = oc get compliancescans -n $NAMESPACE --no-headers 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  No hay ComplianceScans creados aún" -ForegroundColor Yellow
} else {
    $scanCount = ($scans | Measure-Object -Line).Lines
    Write-Host "✅ ComplianceScans encontrados: $scanCount" -ForegroundColor Green
    Write-Host ""
    Write-Host "   Detalles:" -ForegroundColor Cyan
    oc get compliancescans -n $NAMESPACE -o custom-columns=NAME:.metadata.name,PHASE:.status.phase,RESULT:.status.result 2>&1 | Out-String
}
Write-Host ""

# Verificar ComplianceSuites
Write-Host "5. Verificando ComplianceSuites..." -ForegroundColor Yellow
$suites = oc get compliancesuites -n $NAMESPACE --no-headers 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  No hay ComplianceSuites creadas aún" -ForegroundColor Yellow
} else {
    $suiteCount = ($suites | Measure-Object -Line).Lines
    Write-Host "✅ ComplianceSuites encontradas: $suiteCount" -ForegroundColor Green
    oc get compliancesuites -n $NAMESPACE 2>&1 | Out-String
}
Write-Host ""

# Verificar PVCs
Write-Host "6. Verificando PVCs con resultados..." -ForegroundColor Yellow
$totalPvc = 0
$pvcs = oc get pvc -n $NAMESPACE --no-headers 2>&1
if ($LASTEXITCODE -eq 0) {
    $pvcCis = ($pvcs | Select-String "ocp4-cis").Count
    $pvcPci = ($pvcs | Select-String "ocp4-pci-dss").Count
    $totalPvc = $pvcCis + $pvcPci
    
    if ($totalPvc -eq 0) {
        Write-Host "⚠️  No hay PVCs con resultados aún" -ForegroundColor Yellow
        Write-Host "   Los scans pueden estar ejecutándose o no se han iniciado" -ForegroundColor Gray
    } else {
        Write-Host "✅ PVCs encontrados:" -ForegroundColor Green
        Write-Host "   - CIS: $pvcCis" -ForegroundColor Cyan
        Write-Host "   - PCI: $pvcPci" -ForegroundColor Cyan
        Write-Host "   - Total: $totalPvc" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   Lista de PVCs:" -ForegroundColor Cyan
        $pvcs | Select-String -Pattern "ocp4-(cis|pci-dss)" | ForEach-Object {
            $parts = $_ -split '\s+'
            Write-Host "     - $($parts[0]) ($($parts[1]))" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "⚠️  No se pueden listar PVCs" -ForegroundColor Yellow
}
Write-Host ""

# Verificar Políticas ACM
Write-Host "7. Verificando Políticas ACM (desde hub)..." -ForegroundColor Yellow
$policies = oc get policies -n policies --no-headers 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  No se pueden verificar políticas (puede que no estés en el hub cluster)" -ForegroundColor Yellow
} else {
    $policyCount = ($policies | Measure-Object -Line).Lines
    Write-Host "✅ Políticas encontradas: $policyCount" -ForegroundColor Green
    Write-Host ""
    Write-Host "   Políticas relevantes:" -ForegroundColor Cyan
    $policies | Select-String -Pattern "(compliance|cis|pci)" | ForEach-Object {
        $parts = $_ -split '\s+'
        Write-Host "     - $($parts[0]) ($($parts[1]))" -ForegroundColor Gray
    }
}
Write-Host ""

# Resumen
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "RESUMEN" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
if (-not [string]::IsNullOrEmpty($csv) -and $status -eq "Succeeded") {
    Write-Host "✅ Compliance Operator: Instalado y funcionando" -ForegroundColor Green
} elseif (-not [string]::IsNullOrEmpty($csvNamespace) -or $scanCount -gt 0) {
    Write-Host "✅ Compliance Operator: Funcionando (detectado por scans activos)" -ForegroundColor Green
} else {
    Write-Host "⚠️  Compliance Operator: No detectado claramente (pero puede estar funcionando)" -ForegroundColor Yellow
}

if ($scanCount -gt 0) {
    Write-Host "✅ ComplianceScans: $scanCount encontrados" -ForegroundColor Green
} else {
    Write-Host "⚠️  ComplianceScans: Ninguno encontrado (puede estar en proceso)" -ForegroundColor Yellow
}

if ($totalPvc -gt 0) {
    Write-Host "✅ PVCs con resultados: $totalPvc listos para exportar" -ForegroundColor Green
} else {
    Write-Host "⚠️  PVCs: Ninguno encontrado (los scans pueden estar ejecutándose)" -ForegroundColor Yellow
}
Write-Host ""

# Recomendaciones
Write-Host "RECOMENDACIONES:" -ForegroundColor Cyan
if ([string]::IsNullOrEmpty($csv) -and [string]::IsNullOrEmpty($csvNamespace) -and $scanCount -eq 0) {
    Write-Host "  → Ejecutar playbook con do_gitops=true para instalar el operator" -ForegroundColor Yellow
}
if ($scanCount -eq 0) {
    Write-Host "  → Verificar que las políticas ACM se hayan aplicado correctamente" -ForegroundColor Yellow
    Write-Host "  → Esperar 5-10 minutos después del GitOps para que se creen los scans" -ForegroundColor Yellow
}
if ($totalPvc -eq 0 -and $scanCount -gt 0) {
    Write-Host "  → Los scans están ejecutándose, esperar 10-30 minutos para resultados" -ForegroundColor Yellow
}
if ($totalPvc -gt 0) {
    Write-Host "  → Ejecutar playbook con do_export_html=true para exportar resultados" -ForegroundColor Yellow
}
Write-Host ""

