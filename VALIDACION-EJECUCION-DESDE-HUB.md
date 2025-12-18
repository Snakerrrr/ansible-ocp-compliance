# Validación: Ejecución desde HUB Cluster

Este documento describe cómo validar y ejecutar el playbook de compliance desde el cluster HUB (donde está ACM).

## 📋 Contexto

El playbook debe ejecutarse desde el **HUB cluster** porque:
- El proceso es **centralizado** (gestión desde un solo punto)
- ACM (Advanced Cluster Management) está en el HUB
- Las políticas se aplican al cluster objetivo (`cluster-acs`) mediante **PlacementRules** y **Label Selectors**

## 🔍 Validación Previa

Antes de ejecutar el playbook desde el HUB, ejecuta el script de validación:

```bash
cd /mnt/c/Users/Bastián/Desktop/ansible-ocp-compliance
./scripts/validar-ejecucion-desde-hub.sh
```

Este script verifica:
1. ✅ Contexto de OpenShift configurado
2. ✅ Estás en el HUB (recursos de ACM disponibles)
3. ✅ `cluster-acs` está registrado en ACM
4. ✅ `cluster-acs` tiene el label `environment=cluster-acs`
5. ✅ Acceso a PVCs del cluster-acs
6. ✅ Herramientas necesarias instaladas

## 🎯 Label Selector

El label selector está configurado en:
```
roles/toggle_policies/templates/policy-generator-config.yaml.j2
```

Configuración actual:
```yaml
placement:
  labelSelector:
    matchExpressions:
      - key: environment
        operator: In
        values:
          - cluster-acs
```

**IMPORTANTE**: El cluster `cluster-acs` **DEBE** tener el label `environment=cluster-acs` para que las políticas se apliquen correctamente.

### Verificar/Configurar Label

```bash
# Verificar label actual
oc get managedcluster cluster-acs -o jsonpath='{.metadata.labels.environment}'

# Configurar label si no existe
oc label managedcluster cluster-acs environment=cluster-acs
```

## 🚀 Ejecución desde HUB

### Opción 1: Solo GitOps (sin export HTML)

Esta opción funciona desde cualquier lugar porque solo necesita GitHub:

```bash
cd /mnt/c/Users/Bastián/Desktop/ansible-ocp-compliance
export ANSIBLE_ROLES_PATH=$(pwd)/roles
ansible-playbook playbooks/compliance-pipeline.yml \
    -i inventories/localhost.yml \
    -e "github_token=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 \
        do_gitops=true \
        do_export_html=false"
```

**Qué hace:**
- Clona/actualiza el repo `acm-policies`
- Renderiza `policy-generator-config.yaml` con los flags especificados
- Hace commit y push a GitHub
- ArgoCD detecta el cambio y sincroniza
- ACM aplica las políticas al `cluster-acs` mediante PlacementRules

### Opción 2: Export HTML desde HUB (requiere acceso a cluster-acs)

Para exportar HTML desde el HUB, necesitas acceso a los PVCs del `cluster-acs`.

#### Paso 1: Configurar contexto del cluster-acs

```bash
# Opción A: Agregar contexto del cluster-acs
oc config set-context cluster-acs \
    --cluster=<cluster-acs-url> \
    --user=<user> \
    --namespace=openshift-compliance

# Opción B: Verificar que el contexto existe
oc config get-contexts | grep cluster-acs
```

#### Paso 2: Ejecutar playbook con contexto

```bash
cd /mnt/c/Users/Bastián/Desktop/ansible-ocp-compliance
export ANSIBLE_ROLES_PATH=$(pwd)/roles
ansible-playbook playbooks/compliance-pipeline.yml \
    -i inventories/localhost.yml \
    -e "github_token=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 \
        do_gitops=true \
        do_export_html=true \
        target_cluster_context=cluster-acs"
```

**Parámetro clave**: `target_cluster_context=cluster-acs`

Este parámetro hace que todos los comandos `oc` usen `--context=cluster-acs` para acceder a los PVCs del cluster objetivo.

### Opción 3: Pipeline completo desde HUB

```bash
cd /mnt/c/Users/Bastián/Desktop/ansible-ocp-compliance
export ANSIBLE_ROLES_PATH=$(pwd)/roles
ansible-playbook playbooks/compliance-pipeline.yml \
    -i inventories/localhost.yml \
    -e "github_token=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 \
        do_gitops=true \
        do_export_html=true \
        target_cluster_context=cluster-acs \
        run_cis=true \
        run_pci=true"
```

## 🔧 Variables Importantes

| Variable | Descripción | Default | Requerido |
|----------|-------------|---------|-----------|
| `do_gitops` | Ejecutar GitOps (commit + push) | `false` | No |
| `do_export_html` | Exportar resultados a HTML | `false` | No |
| `target_cluster_context` | Contexto de oc para acceder a PVCs | `""` | Solo si export HTML desde HUB |
| `run_cis` | Ejecutar scan CIS | `true` | No |
| `run_pci` | Ejecutar scan PCI | `true` | No |
| `github_token` | Token de GitHub para GitOps | - | Si `do_gitops=true` |

## ✅ Checklist de Validación

Antes de ejecutar desde el HUB, verifica:

- [ ] Estás logueado al HUB cluster (`oc config current-context`)
- [ ] `cluster-acs` está registrado en ACM (`oc get managedcluster cluster-acs`)
- [ ] `cluster-acs` tiene label `environment=cluster-acs`
- [ ] Contexto `cluster-acs` configurado (si vas a exportar HTML)
- [ ] Puedes acceder a PVCs: `oc get pvc -n openshift-compliance --context=cluster-acs`
- [ ] Herramientas instaladas: `ansible-playbook`, `oc`, `oscap`, `git`

## 🧪 Pruebas Recomendadas

### Test 1: Validar Label Selector

```bash
# Verificar que las políticas se aplican al cluster correcto
oc get placementrule -n policies
oc get placementbinding -n policies

# Verificar que las políticas están aplicadas
oc get policies -n policies
oc describe policy run-cis-scan -n policies
```

### Test 2: Validar Acceso a PVCs desde HUB

```bash
# Debe funcionar si el contexto está configurado
oc get pvc -n openshift-compliance --context=cluster-acs

# Debe mostrar PVCs de CIS y PCI
oc get pvc -n openshift-compliance --context=cluster-acs | grep -E "ocp4-cis|ocp4-pci-dss"
```

### Test 3: Ejecutar solo GitOps (más seguro primero)

```bash
ansible-playbook playbooks/compliance-pipeline.yml \
    -i inventories/localhost.yml \
    -e "github_token=XXX do_gitops=true do_export_html=false"
```

Verificar:
- Commit visible en GitHub
- ArgoCD sincroniza
- Políticas aplicadas en ACM

### Test 4: Ejecutar Export HTML desde HUB

```bash
ansible-playbook playbooks/compliance-pipeline.yml \
    -i inventories/localhost.yml \
    -e "do_gitops=false do_export_html=true target_cluster_context=cluster-acs"
```

Verificar:
- PVCs encontrados correctamente
- Archivos HTML generados
- Archivos intermedios eliminados

## 🚨 Troubleshooting

### Problema: No se encuentran PVCs

**Causa**: Contexto del cluster-acs no configurado o incorrecto

**Solución**:
```bash
# Verificar contexto
oc config get-contexts

# Configurar contexto
oc config set-context cluster-acs --cluster=<url> --user=<user>

# Probar acceso
oc get pvc -n openshift-compliance --context=cluster-acs
```

### Problema: Políticas no se aplican al cluster-acs

**Causa**: Label selector no coincide

**Solución**:
```bash
# Verificar label
oc get managedcluster cluster-acs -o jsonpath='{.metadata.labels.environment}'

# Configurar label
oc label managedcluster cluster-acs environment=cluster-acs

# Verificar PlacementRule
oc get placementrule -n policies -o yaml
```

### Problema: Error "context not found"

**Causa**: El contexto `cluster-acs` no existe en `~/.kube/config`

**Solución**:
```bash
# Agregar contexto manualmente o usar login directo
oc login <cluster-acs-url>

# O configurar contexto
oc config set-context cluster-acs --cluster=<cluster-url> --user=<user>
```

## 📝 Notas Importantes

1. **GitOps funciona desde cualquier lugar**: Solo necesita acceso a GitHub
2. **Export HTML requiere acceso al cluster objetivo**: Necesita contexto o acceso directo
3. **Label selector es crítico**: Debe coincidir exactamente con el label del cluster
4. **PlacementRules se crean automáticamente**: PolicyGenerator las genera basándose en el label selector

## 🎯 Siguiente Paso

Una vez validado que funciona desde el HUB:
1. ✅ Integrar con AAP (Ansible Automation Platform)
2. ✅ Crear Job Template en AAP
3. ✅ Configurar Survey con variables
4. ✅ Crear Credential para `github_token`
5. ✅ Ejecutar desde AAP UI

---

**Última actualización**: Script de validación y soporte para ejecución desde HUB agregado.

