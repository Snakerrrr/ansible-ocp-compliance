# 📋 Resumen Rápido - Qué Debería Verse Reflejado

## 🎯 Objetivo
Validar que los cambios se reflejen correctamente en el cluster-acs después de ejecutar el pipeline.

---

## 🔄 PASO 1: Ejecutar GitOps

### Comando:
```bash
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "github_token=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 \
      do_gitops=true do_export_html=false \
      run_cis=true run_pci=true"
```

### ✅ Qué Debería Verse:

#### En Ansible Output:
- ✅ "Clonar/actualizar repo GitOps" → OK
- ✅ "Renderizar policy-generator-config.yaml" → OK  
- ✅ "Hacer commit y push si hay cambios" → OK
- ✅ "Cambios GitOps aplicados exitosamente" → OK

#### En GitHub (repo: acm-policies):
1. **Nuevo commit** con mensaje: `"Compliance GitOps update (CIS=True, PCI=True, remediation=inform)"`
2. **Archivo modificado**: `base/policy-generator-config.yaml`
3. **Contenido esperado**:
   ```yaml
   policies:
     - name: run-cis-scan
       disabled: false  # ← Debe ser false
       remediationAction: inform
     - name: run-pci-scan
       disabled: false  # ← Debe ser false
       remediationAction: inform
   ```

#### En ArgoCD (si tienes acceso):
- ✅ Aplicación muestra "Synced" (verde)
- ✅ Sync automático detectado
- ✅ Estado: "Healthy"

---

## 🔍 PASO 2: Verificar en Cluster (cluster-acs)

### Conectarse:
```bash
oc login <cluster-acs-url>
oc project openshift-compliance
```

### Comandos de Verificación:

#### 1. Compliance Operator
```bash
oc get csv -n openshift-compliance | grep compliance-operator
```
**✅ Esperado**: `compliance-operator.vX.X.X    Succeeded`

#### 2. ComplianceScans
```bash
oc get compliancescans -n openshift-compliance
```
**✅ Esperado** (después de 5-10 min):
```
NAME              PHASE     RESULT
ocp4-cis          RUNNING   NOT-AVAILABLE
ocp4-pci-dss      RUNNING   NOT-AVAILABLE
```

**✅ Esperado** (después de 30+ min):
```
NAME              PHASE     RESULT
ocp4-cis          DONE      NON-COMPLIANT (o COMPLIANT)
ocp4-pci-dss      DONE      NON-COMPLIANT (o COMPLIANT)
```

#### 3. PVCs con Resultados
```bash
oc get pvc -n openshift-compliance
```
**✅ Esperado** (después de que scans terminen):
```
NAME                      STATUS   CAPACITY
ocp4-cis-node-master      Bound    1Gi
ocp4-cis-node-worker      Bound    1Gi
ocp4-pci-dss-node-*       Bound    1Gi
```

#### 4. Políticas ACM (desde hub cluster)
```bash
oc get policies -n policies | grep compliance
```
**✅ Esperado**:
```
install-compliance-operator    Compliant
run-cis-scan                   Compliant
run-pci-scan                   Compliant
```

---

## 📊 PASO 3: Exportar HTML

### Comando:
```bash
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "do_gitops=false do_export_html=true"
```

### ✅ Qué Debería Verse:

#### En Ansible Output:
- ✅ "Verificar que oc está disponible" → OK
- ✅ "Verificar que oscap está disponible" → OK
- ✅ "PVCs CIS encontrados: [...]" → Lista de PVCs
- ✅ "PVCs PCI encontrados: [...]" → Lista de PVCs
- ✅ "Crear pod extractor temporal" → OK
- ✅ "Copiar resultados desde PVC" → OK
- ✅ "Conversión XML → HTML" → OK
- ✅ "Reportes exportados exitosamente" → OK

#### En el Sistema de Archivos:
**Ubicación**: `/tmp/compliance-reports/` (o el directorio especificado)

**Estructura esperada**:
```
/tmp/compliance-reports/
├── ocp4-cis-node-master/
│   ├── arf.xml
│   ├── arf.html          ← Abrir en navegador
│   └── xccdf-results.xml
├── ocp4-cis-node-worker/
│   ├── arf.xml
│   ├── arf.html
│   └── xccdf-results.xml
├── ocp4-pci-dss-*/
│   ├── arf.xml
│   ├── arf.html
│   └── xccdf-results.xml
├── summary.txt           ← Resumen de PVCs procesados
└── compliance-reports-<timestamp>.zip  ← ZIP compartible
```

#### Verificar Contenido:
```bash
# Ver resumen
cat /tmp/compliance-reports/summary.txt

# Abrir reporte HTML
# (Abrir arf.html en navegador)
```

---

## ⏱️ Timeline Esperado

| Tiempo | Evento | Dónde Verificar |
|--------|--------|-----------------|
| **T+0 min** | Playbook ejecuta GitOps | Ansible output |
| **T+0 min** | Commit + Push a GitHub | GitHub repo |
| **T+1-2 min** | ArgoCD detecta cambio | ArgoCD UI |
| **T+2-5 min** | ACM aplica políticas | `oc get policies` |
| **T+5-10 min** | Scans creados en cluster | `oc get compliancescans` |
| **T+10-30 min** | Scans ejecutándose | `oc get compliancescans` (PHASE=RUNNING) |
| **T+30+ min** | Scans completados, PVCs listos | `oc get pvc` |
| **T+30+ min** | Export HTML disponible | `/tmp/compliance-reports/` |

---

## 🚨 Señales de Problema

### ❌ GitOps no funciona:
- **Síntoma**: No hay commit en GitHub
- **Causa**: Token inválido o sin permisos
- **Solución**: Verificar token y permisos de repo

### ❌ Scans no se crean:
- **Síntoma**: `oc get compliancescans` vacío después de 10 min
- **Causa**: Políticas no aplicadas o Placement incorrecto
- **Solución**: Verificar `oc get policies -n policies`

### ❌ Scans no terminan:
- **Síntoma**: PHASE=RUNNING por más de 1 hora
- **Causa**: Problemas en el cluster o recursos insuficientes
- **Solución**: `oc describe compliancescan <nombre>` para ver logs

### ❌ Export HTML falla:
- **Síntoma**: Error al copiar desde PVC
- **Causa**: No logueado al cluster o PVCs no existen
- **Solución**: `oc login` y verificar `oc get pvc`

---

## ✅ Checklist de Validación

Marca cada ítem cuando lo verifiques:

- [ ] **GitOps**: Commit visible en GitHub
- [ ] **GitOps**: policy-generator-config.yaml actualizado correctamente
- [ ] **ArgoCD**: Sync automático detectado (si tienes acceso)
- [ ] **ACM**: Políticas aplicadas al cluster-acs
- [ ] **Cluster**: Compliance Operator instalado
- [ ] **Cluster**: ComplianceScans creados (después de 5-10 min)
- [ ] **Cluster**: ComplianceScans en estado RUNNING o DONE
- [ ] **Cluster**: PVCs con resultados generados (después de 30+ min)
- [ ] **Export**: Reportes HTML generados correctamente
- [ ] **Export**: ZIP creado con todos los reportes
- [ ] **Export**: summary.txt contiene información correcta

---

## 🎯 Siguiente Paso

Una vez validado todo:
1. ✅ Crear Job Template en AAP
2. ✅ Configurar Survey con variables
3. ✅ Crear Credential para github_token
4. ✅ Ejecutar desde AAP UI

---

## 📞 Scripts de Ayuda

Usa los scripts de verificación rápida:

**Linux/Mac:**
```bash
chmod +x scripts/verificar-cluster.sh
./scripts/verificar-cluster.sh
```

**Windows (PowerShell):**
```powershell
.\scripts\verificar-cluster.ps1
```

Estos scripts verifican automáticamente:
- Conexión al cluster
- Compliance Operator
- ComplianceScans
- ComplianceSuites
- PVCs con resultados
- Políticas ACM

