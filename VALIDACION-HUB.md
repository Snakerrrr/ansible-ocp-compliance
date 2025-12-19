# Validación: Ejecución desde el HUB

Este documento describe cómo validar que el playbook funcione correctamente cuando se ejecuta desde el **HUB** (donde está ACM) en lugar de desde el cluster-acs.

## Cambios Realizados

### 1. Label Selector Configurable

El label selector en `policy-generator-config.yaml` ahora es configurable mediante variables:

- **`placement_label_key`**: Clave del label (default: `environment`)
- **`placement_label_value`**: Valor del label (default: `cluster-acs`)

**Archivo modificado**: `roles/toggle_policies/templates/policy-generator-config.yaml.j2`

```yaml
placement:
  labelSelector:
    matchExpressions:
      - key: {{ placement_label_key | default('environment') }}
        operator: In
        values:
          - {{ placement_label_value | default('cluster-acs') }}
```

### 2. Soporte para Contexto de Cluster en Export HTML

El rol `compliance_export_html` ahora soporta especificar el contexto del cluster objetivo cuando se ejecuta desde el HUB:

- **`target_cluster_context`**: Contexto de OpenShift del cluster objetivo (ej: `cluster-acs`)

**Archivos modificados**:
- `roles/compliance_export_html/tasks/main.yml`
- `roles/compliance_export_html/tasks/process_pvc.yml`

Todos los comandos `oc` ahora usan `--context=<target_cluster_context>` cuando se especifica.

### 3. Variables del Playbook

El playbook principal ahora acepta las siguientes variables adicionales:

```yaml
# ACM Placement configuration
placement_label_key: "environment"        # Default
placement_label_value: "cluster-acs"      # Default

# Cluster context for export
target_cluster_context: ""                # Si está vacío, usa contexto actual
```

## Scripts de Validación

Se crearon dos scripts para validar la configuración antes de ejecutar el playbook:

### Bash (Linux/WSL)
```bash
./scripts/validar-desde-hub.sh
```

### PowerShell (Windows)
```powershell
.\scripts\validar-desde-hub.ps1
```

Estos scripts verifican:
1. ✅ Contexto actual de OpenShift
2. ✅ Acceso al HUB (ACM)
3. ✅ Clusters gestionados disponibles
4. ✅ Label selector configurado
5. ✅ Label en el cluster objetivo
6. ✅ Políticas ACM existentes
7. ✅ Acceso al cluster objetivo (si se especifica)

## Cómo Validar

### Paso 1: Ejecutar Script de Validación

Desde el HUB, ejecuta el script de validación:

```bash
# Desde WSL/Linux
./scripts/validar-desde-hub.sh

# Desde PowerShell
.\scripts\validar-desde-hub.ps1
```

El script mostrará:
- Si estás en el contexto correcto (HUB)
- Si el cluster objetivo tiene el label necesario
- Si puedes acceder a los recursos necesarios

### Paso 2: Verificar Label en el Cluster Objetivo

Asegúrate de que el cluster objetivo tenga el label configurado:

```bash
# Verificar label actual
oc get managedcluster cluster-acs -o jsonpath='{.metadata.labels}'

# Si no tiene el label, agregarlo:
oc label managedcluster cluster-acs environment=cluster-acs
```

### Paso 3: Configurar Kubeconfigs de Managed Clusters

**IMPORTANTE**: Antes de ejecutar el playbook, necesitas tener los kubeconfigs de los managed clusters configurados.

#### Opción 1: Variable managed_cluster_kubeconfigs (Recomendado para múltiples clusters)

```bash
# Configurar kubeconfigs para múltiples clusters
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "github_token=XXX do_gitops=true do_export_html=true \
      placement_label_key=environment \
      placement_label_value=cluster-acs \
      target_cluster_context=cluster-acs \
      managed_cluster_kubeconfigs='{\"cluster-acs\": \"/tmp/kubeconfig-cluster-acs\", \"cluster-2\": \"/tmp/kubeconfig-cluster-2\"}'"
```

#### Opción 2: Ubicación por defecto (un solo cluster)

Si solo trabajas con un cluster, puedes guardar el kubeconfig en la ubicación por defecto:

```bash
# Guardar kubeconfig en ubicación por defecto
cp /ruta/al/kubeconfig /tmp/kubeconfig-cluster-acs
chmod 600 /tmp/kubeconfig-cluster-acs

# Ejecutar playbook (detectará automáticamente el kubeconfig)
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "github_token=XXX do_gitops=true do_export_html=true \
      placement_label_key=environment \
      placement_label_value=cluster-acs \
      target_cluster_context=cluster-acs"
```

### Paso 4: Ejecutar Playbook desde el HUB

**IMPORTANTE**: **SIEMPRE usa el script wrapper** para evitar errores de roles no encontrados:

```bash
./scripts/ejecutar-playbook-hub.sh -e "github_token=XXX ..."
```

El script configura automáticamente `ANSIBLE_ROLES_PATH` y evita errores comunes.

**Alternativa manual** (no recomendado):

```bash
export ANSIBLE_ROLES_PATH=$(pwd)/roles
ansible-playbook playbooks/compliance-pipeline.yml -i inventories/localhost.yml ...
```

#### Opción A: Solo GitOps (toggle policies)

```bash
export ANSIBLE_ROLES_PATH=$(pwd)/roles
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "github_token=XXX do_gitops=true do_export_html=false \
      placement_label_key=environment \
      placement_label_value=cluster-acs"
```

**Qué hace**:
- Renderiza `policy-generator-config.yaml` con el label selector configurado
- Hace commit y push al repo GitOps
- ArgoCD sincroniza automáticamente
- Las políticas se aplican al cluster con el label `environment=cluster-acs`

#### Opción B: Solo Export HTML (desde HUB)

```bash
export ANSIBLE_ROLES_PATH=$(pwd)/roles
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "do_gitops=false do_export_html=true \
      target_cluster_context=cluster-acs \
      managed_cluster_kubeconfigs='{\"cluster-acs\": \"/tmp/kubeconfig-cluster-acs\"}'"
```

**Qué hace**:
- Se conecta al cluster `cluster-acs` usando el kubeconfig especificado
- Extrae resultados de PVCs desde `cluster-acs`
- Genera reportes HTML
- Limpia archivos intermedios

#### Opción C: Pipeline Completo (GitOps + Export HTML)

```bash
export ANSIBLE_ROLES_PATH=$(pwd)/roles
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "github_token=XXX do_gitops=true do_export_html=true \
      placement_label_key=environment \
      placement_label_value=cluster-acs \
      target_cluster_context=cluster-acs \
      managed_cluster_kubeconfigs='{\"cluster-acs\": \"/tmp/kubeconfig-cluster-acs\"}'"
```

**Alternativa usando script wrapper**:

```bash
./scripts/ejecutar-playbook-hub.sh \
  -e "github_token=XXX do_gitops=true do_export_html=true \
      placement_label_key=environment \
      placement_label_value=cluster-acs \
      target_cluster_context=cluster-acs \
      managed_cluster_kubeconfigs='{\"cluster-acs\": \"/tmp/kubeconfig-cluster-acs\"}'"
```

#### Opción D: Múltiples Clusters

Para trabajar con múltiples clusters, configura todos los kubeconfigs en la variable:

```bash
export ANSIBLE_ROLES_PATH=$(pwd)/roles
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "github_token=XXX do_gitops=true do_export_html=true \
      placement_label_key=environment \
      placement_label_value=cluster-acs \
      target_cluster_context=cluster-acs \
      managed_cluster_kubeconfigs='{\"cluster-acs\": \"/tmp/kubeconfig-cluster-acs\", \"cluster-2\": \"/tmp/kubeconfig-cluster-2\"}'"
```

## Verificación Post-Ejecución

### 1. Verificar Políticas en el HUB

```bash
# Ver políticas aplicadas
oc get policies -n policies

# Ver detalles de una política
oc get policy install-compliance-operator -n policies -o yaml

# Ver placement bindings
oc get placementbindings -n policies
```

### 2. Verificar Aplicación en el Cluster Objetivo

```bash
# Cambiar contexto al cluster objetivo
oc config use-context cluster-acs

# Verificar Compliance Operator
oc get csv -n openshift-compliance

# Verificar ComplianceScans
oc get compliancescans -n openshift-compliance

# Verificar PVCs con resultados
oc get pvc -n openshift-compliance
```

### 3. Verificar Label Selector

El label selector debe coincidir con el label del managed cluster:

```bash
# Ver label del managed cluster
oc get managedcluster cluster-acs -o jsonpath='{.metadata.labels.environment}'

# Debe retornar: cluster-acs
```

## Troubleshooting

### Error: "No se puede acceder al cluster objetivo"

**Causa**: El contexto especificado no existe o no tienes acceso.

**Solución**:
```bash
# Listar contextos disponibles
oc config get-contexts

# Verificar acceso al contexto
oc get nodes --context=cluster-acs
```

### Error: "Políticas no se aplican al cluster objetivo"

**Causa**: El cluster objetivo no tiene el label configurado.

**Solución**:
```bash
# Agregar label al managed cluster
oc label managedcluster cluster-acs environment=cluster-acs

# Verificar que se aplicó
oc get managedcluster cluster-acs -o yaml | grep -A 5 labels
```

### Error: "No se encuentran PVCs en el cluster objetivo"

**Causa**: Los scans aún no han completado o el namespace es incorrecto.

**Solución**:
```bash
# Verificar scans en progreso
oc get compliancescans -n openshift-compliance --context=cluster-acs

# Verificar PVCs
oc get pvc -n openshift-compliance --context=cluster-acs

# Esperar a que los scans completen (puede tardar 10-30 minutos)
```

## Checklist de Validación

Antes de integrar en AAP, verifica:

- [ ] Script de validación ejecuta sin errores
- [ ] Label selector está configurado correctamente
- [ ] Cluster objetivo tiene el label necesario
- [ ] GitOps funciona desde el HUB (commit + push)
- [ ] Políticas se aplican al cluster objetivo
- [ ] Export HTML funciona desde el HUB con `target_cluster_context`
- [ ] Reportes HTML se generan correctamente
- [ ] Archivos intermedios se limpian automáticamente

## Próximos Pasos

Una vez validado todo:

1. ✅ Crear Job Template en AAP
2. ✅ Configurar Survey con las variables:
   - `github_token` (Credential)
   - `do_gitops` (boolean)
   - `do_export_html` (boolean)
   - `placement_label_key` (string, default: environment)
   - `placement_label_value` (string, default: cluster-acs)
   - `target_cluster_context` (string, opcional)
3. ✅ Ejecutar desde AAP UI

---

**Nota**: El playbook ahora es completamente funcional desde el HUB, permitiendo gestión centralizada de compliance para múltiples clusters gestionados por ACM.

