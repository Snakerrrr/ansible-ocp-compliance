# Guía de Validación - Compliance Pipeline OCP

Esta guía te ayudará a validar que todo el pipeline funcione correctamente antes de integrarlo con AAP.

## 📋 Prerequisitos

1. **Ansible instalado**:
   ```bash
   pip install ansible
   ```

2. **Acceso al cluster cluster-acs**:
   ```bash
   oc login <cluster-url> -u <usuario>
   oc project openshift-compliance
   ```

3. **Acceso a GitHub** con token válido (ya lo tienes)

4. **oscap instalado** (solo para export HTML):
   ```bash
   # En RHEL/CentOS
   yum install openscap-scanner
   ```

---

## 🔄 FASE 1: Validar GitOps (Activar Scans)

### Ejecutar Playbook

```bash
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "github_token=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 \
      do_gitops=true \
      do_export_html=false \
      run_cis=true \
      run_pci=true \
      scan_remediation_action=inform"
```

### ✅ Qué debería pasar:

1. **En el output de Ansible**:
   - ✅ Clonar/actualizar repo GitOps exitosamente
   - ✅ Renderizar policy-generator-config.yaml
   - ✅ Detectar cambios en el repo
   - ✅ Commit y push exitosos
   - ✅ Mensaje: "Cambios GitOps aplicados exitosamente"

2. **En GitHub (repo acm-policies)**:
   - ✅ Ver un nuevo commit con mensaje: "Compliance GitOps update (CIS=True, PCI=True, remediation=inform)"
   - ✅ El archivo `base/policy-generator-config.yaml` debe tener:
     ```yaml
     policies:
       - name: run-cis-scan
         disabled: false  # ← Debe estar en false
         remediationAction: inform
       - name: run-pci-scan
         disabled: false  # ← Debe estar en false
         remediationAction: inform
     ```

3. **En ArgoCD (si tienes acceso)**:
   - ✅ ArgoCD detecta el cambio automáticamente
   - ✅ Sync automático o manual
   - ✅ Aplicación muestra "Synced" y "Healthy"

4. **En ACM Hub (Advanced Cluster Management)**:
   - ✅ Las políticas se propagan al cluster-acs
   - ✅ Puedes verificar con:
     ```bash
     oc get policies -n policies
     ```

---

## 🔍 FASE 2: Verificar en el Cluster Objetivo (cluster-acs)

### Conectarse al cluster

```bash
oc login <cluster-acs-url> -u <usuario>
oc project openshift-compliance
```

### Verificar Compliance Operator

```bash
# Verificar que el operator esté instalado
oc get csv -n openshift-compliance | grep compliance-operator

# Debe mostrar: compliance-operator.vX.X.X (Succeeded)
```

### Verificar ComplianceScans

```bash
# Ver todos los scans
oc get compliancescans -n openshift-compliance

# Debe mostrar algo como:
# NAME              PHASE     RESULT
# ocp4-cis          RUNNING   NOT-AVAILABLE
# ocp4-pci-dss      RUNNING   NOT-AVAILABLE

# O si ya terminaron:
# NAME              PHASE     RESULT
# ocp4-cis          DONE      NON-COMPLIANT
# ocp4-pci-dss      DONE      NON-COMPLIANT
```

### Verificar ComplianceSuites

```bash
oc get compliancesuites -n openshift-compliance

# Debe mostrar suites relacionadas con CIS y PCI
```

### Verificar PVCs con Resultados

```bash
# Ver PVCs creados
oc get pvc -n openshift-compliance

# Debe mostrar algo como:
# NAME                    STATUS   VOLUME   CAPACITY
# ocp4-cis-node-master    Bound    ...     1Gi
# ocp4-cis-node-worker    Bound    ...     1Gi
# ocp4-pci-dss-node-*     Bound    ...     1Gi
```

### Verificar Detalles de un Scan

```bash
# Ver detalles de un scan específico
oc describe compliancescan ocp4-cis -n openshift-compliance

# Verificar el estado
oc get compliancescan ocp4-cis -n openshift-compliance -o yaml
```

### ✅ Qué debería verse:

- ✅ **Compliance Operator**: Instalado y funcionando
- ✅ **ComplianceScans**: En estado RUNNING o DONE
- ✅ **PVCs**: Creados y Bound con resultados
- ✅ **ComplianceSuites**: Ejecutándose o completadas

---

## 📊 FASE 3: Exportar Resultados HTML

### Ejecutar Playbook de Export

```bash
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "do_gitops=false \
      do_export_html=true \
      export_output_dir=/tmp/compliance-reports"
```

### ✅ Qué debería pasar:

1. **En el output de Ansible**:
   - ✅ Verificar que `oc` está disponible
   - ✅ Verificar que `oscap` está disponible
   - ✅ Detectar PVCs CIS y PCI
   - ✅ Crear pods extractores temporales
   - ✅ Copiar resultados desde PVCs
   - ✅ Convertir XML → HTML
   - ✅ Generar summary.txt
   - ✅ Crear ZIP con todos los reportes

2. **En el directorio de salida** (`/tmp/compliance-reports`):
   ```
   /tmp/compliance-reports/
   ├── ocp4-cis-node-master/
   │   ├── arf.xml
   │   ├── arf.html          ← Reporte HTML navegable
   │   └── ...
   ├── ocp4-cis-node-worker/
   │   ├── arf.xml
   │   ├── arf.html
   │   └── ...
   ├── ocp4-pci-dss-*/
   │   ├── arf.xml
   │   ├── arf.html
   │   └── ...
   ├── summary.txt           ← Resumen de PVCs procesados
   └── compliance-reports-<timestamp>.zip  ← ZIP compartible
   ```

3. **Verificar contenido del summary.txt**:
   ```bash
   cat /tmp/compliance-reports/summary.txt
   ```

---

## 🔄 FASE 4: Validar Cambios Reflejados

### Timeline Esperado

1. **T+0 min**: Playbook ejecuta GitOps (commit + push)
2. **T+1-2 min**: ArgoCD detecta cambio y sincroniza
3. **T+2-5 min**: ACM aplica políticas al cluster-acs
4. **T+5-10 min**: Compliance Operator crea/actualiza scans
5. **T+10-30 min**: Scans ejecutan y generan resultados
6. **T+30+ min**: PVCs con resultados listos para exportar

### Verificar Estado de Políticas en ACM

```bash
# Desde el hub cluster
oc get policies -n policies

# Ver detalles de una política
oc describe policy install-compliance-operator -n policies
oc describe policy run-cis-scan -n policies
oc describe policy run-pci-scan -n policies
```

### Verificar Placement

```bash
# Verificar que las políticas se aplican al cluster correcto
oc get placementbinding -n policies
oc get placementrule -n policies
```

---

## 🧪 Casos de Prueba Adicionales

### Test 1: Solo CIS (sin PCI)

```bash
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "github_token=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 \
      do_gitops=true \
      do_export_html=false \
      run_cis=true \
      run_pci=false"
```

**Verificar**: En `policy-generator-config.yaml`:
- `run-cis-scan.disabled: false`
- `run-pci-scan.disabled: true`

### Test 2: Solo PCI (sin CIS)

```bash
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "github_token=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 \
      do_gitops=true \
      do_export_html=false \
      run_cis=false \
      run_pci=true"
```

### Test 3: Pipeline Completo

```bash
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "github_token=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 \
      do_gitops=true \
      do_export_html=true \
      run_cis=true \
      run_pci=true"
```

---

## 🚨 Troubleshooting

### Problema: GitOps no hace commit

**Causa**: No hay cambios detectados
**Solución**: Verificar que los valores de `run_cis` o `run_pci` sean diferentes a los actuales en el repo

### Problema: ArgoCD no sincroniza

**Causa**: ArgoCD no está configurado o no detecta cambios
**Solución**: 
- Verificar que ArgoCD está monitoreando el repo
- Forzar sync manual desde ArgoCD UI

### Problema: Scans no se ejecutan en el cluster

**Causa**: 
- Compliance Operator no instalado
- Placement incorrecto
- Políticas no aplicadas

**Solución**:
```bash
# Verificar operator
oc get csv -n openshift-compliance

# Verificar políticas
oc get policies -n policies

# Verificar placement
oc get placementrule -n policies
```

### Problema: Export HTML falla

**Causa**: 
- No estás logueado al cluster
- oscap no instalado
- PVCs no existen aún

**Solución**:
```bash
# Loguearse al cluster
oc login <cluster-url>

# Instalar oscap
yum install openscap-scanner

# Verificar PVCs
oc get pvc -n openshift-compliance
```

---

## ✅ Checklist de Validación Final

- [ ] GitOps ejecuta correctamente (commit + push)
- [ ] Cambios visibles en GitHub (repo acm-policies)
- [ ] ArgoCD sincroniza automáticamente
- [ ] Políticas aplicadas en ACM Hub
- [ ] Compliance Operator instalado en cluster-acs
- [ ] ComplianceScans creados y ejecutándose
- [ ] PVCs con resultados generados
- [ ] Export HTML funciona correctamente
- [ ] Reportes HTML navegables generados
- [ ] ZIP con reportes creado exitosamente

---

## 📝 Notas Importantes

1. **Timing**: Los scans pueden tardar 10-30 minutos en completarse
2. **Remediation Action**: `inform` solo reporta, no aplica cambios automáticamente
3. **Cluster Label**: Asegúrate que cluster-acs tenga el label `environment=cluster-acs`
4. **Namespace**: Todo se ejecuta en `openshift-compliance`

---

## 🎯 Siguiente Paso

Una vez validado todo, estarás listo para:
1. Crear Job Template en AAP
2. Configurar Survey con las variables
3. Crear Credential para github_token
4. Ejecutar desde AAP UI

