# Configuración de Placement Multi-Cluster con Etiquetas

Este documento explica cómo configurar el placement de ACM para aplicar las políticas de compliance a múltiples clusters usando etiquetas funcionales.

## 🎯 Objetivo

Aplicar las políticas de compliance automáticamente a todos los clusters que tengan la etiqueta `compliance=enabled`, en lugar de estar limitado a un solo cluster específico.

## 📋 Configuración Actual

### Placement por Defecto

El playbook ahora está configurado para usar **etiquetas funcionales** (best practice):

```yaml
placement:
  labelSelector:
    matchLabels:
      compliance: "enabled"
```

Esto significa que **cualquier cluster con la etiqueta `compliance=enabled` recibirá automáticamente las políticas**.

### Ventajas de esta Configuración

1. **Escalable**: Agregar nuevos clusters es tan simple como etiquetarlos
2. **Mantenible**: No necesitas modificar GitOps cada vez que agregas un cluster
3. **Funcional**: La etiqueta describe la función ("¿debe ser auditado?") en lugar del nombre del entorno
4. **Estable**: El código en Git permanece estable, solo cambias etiquetas en el Hub

## 🔧 Cómo Etiquetar Clusters

### Opción 1: Etiquetar desde el Hub (Recomendado)

```bash
# Etiquetar un cluster específico
oc label managedcluster <nombre-cluster> compliance=enabled

# Ejemplo: Etiquetar cluster-acs y cluster-2
oc label managedcluster cluster-acs compliance=enabled
oc label managedcluster cluster-2 compliance=enabled

# Verificar que la etiqueta se aplicó
oc get managedcluster --show-labels
```

### Opción 2: Etiquetar Múltiples Clusters a la Vez

```bash
# Etiquetar todos los clusters que coincidan con un selector
oc label managedcluster -l environment=production compliance=enabled

# O etiquetar todos los clusters manualmente
for cluster in cluster-acs cluster-2 cluster-prod; do
  oc label managedcluster $cluster compliance=enabled
done
```

### Opción 3: Usar un Archivo YAML

```yaml
apiVersion: cluster.open-cluster-management.io/v1
kind: ManagedCluster
metadata:
  name: cluster-acs
  labels:
    compliance: enabled
```

Aplicar con:
```bash
oc apply -f managedcluster-cluster-acs.yaml
```

## 🔍 Verificar Configuración

### 1. Verificar Etiquetas de Clusters

```bash
# Ver todos los clusters y sus etiquetas
oc get managedcluster --show-labels

# Ver solo clusters con la etiqueta compliance=enabled
oc get managedcluster -l compliance=enabled
```

### 2. Verificar Placement en GitOps

Después de ejecutar el playbook, verifica que el `policy-generator-config.yaml` tenga la configuración correcta:

```bash
cat /tmp/acm-policies/base/policy-generator-config.yaml | grep -A 5 placement
```

Deberías ver:
```yaml
placement:
  labelSelector:
    matchLabels:
      compliance: "enabled"
```

### 3. Verificar Políticas en ACM

```bash
# Ver políticas creadas
oc get policies -n policies

# Ver detalles del placement de una política
oc get policy install-compliance-operator -n policies -o yaml | grep -A 10 placement
```

## 🚀 Ejecutar el Playbook

### Con Configuración por Defecto (compliance=enabled)

```bash
# Ejecutar GitOps (aplicará a todos los clusters con compliance=enabled)
./scripts/ejecutar-playbook-hub.sh \
  -e "do_gitops=true do_export_html=false github_token=XXX"
```

### Con Etiquetas Personalizadas

Si necesitas usar etiquetas diferentes (por ejemplo, para migración gradual):

```bash
# Usar environment=cluster-acs (comportamiento anterior)
./scripts/ejecutar-playbook-hub.sh \
  -e "do_gitops=true \
      placement_label_key=environment \
      placement_label_value=cluster-acs \
      github_token=XXX"
```

### Con matchExpressions (si necesitas múltiples valores)

Si necesitas seleccionar múltiples valores, puedes usar `matchExpressions`:

```bash
# Usar matchExpressions en lugar de matchLabels
./scripts/ejecutar-playbook-hub.sh \
  -e "do_gitops=true \
      placement_use_matchlabels=false \
      placement_label_key=environment \
      placement_label_value=cluster-acs \
      github_token=XXX"
```

## 📝 Migración desde Configuración Anterior

Si anteriormente usabas `environment: cluster-acs`, puedes migrar de dos formas:

### Opción A: Etiquetar Clusters Existentes (Recomendado)

```bash
# Agregar la nueva etiqueta a los clusters existentes
oc label managedcluster cluster-acs compliance=enabled
oc label managedcluster cluster-2 compliance=enabled

# Ejecutar el playbook con la nueva configuración
./scripts/ejecutar-playbook-hub.sh \
  -e "do_gitops=true do_export_html=false github_token=XXX"
```

### Opción B: Mantener Configuración Anterior Temporalmente

Si no puedes etiquetar los clusters inmediatamente, puedes seguir usando la configuración anterior:

```bash
./scripts/ejecutar-playbook-hub.sh \
  -e "do_gitops=true \
      placement_label_key=environment \
      placement_label_value=cluster-acs \
      github_token=XXX"
```

## 🎛️ Variables de Configuración

| Variable | Default | Descripción |
|----------|---------|-------------|
| `placement_label_key` | `compliance` | Clave de la etiqueta para el selector |
| `placement_label_value` | `enabled` | Valor de la etiqueta para el selector |
| `placement_use_matchlabels` | `true` | Usar `matchLabels` (simple) en lugar de `matchExpressions` |

## 🔄 Flujo Completo Multi-Cluster

1. **Etiquetar Clusters**:
   ```bash
   oc label managedcluster cluster-acs compliance=enabled
   oc label managedcluster cluster-2 compliance=enabled
   ```

2. **Ejecutar GitOps** (aplica políticas a todos los clusters etiquetados):
   ```bash
   ./scripts/ejecutar-playbook-hub.sh \
     -e "do_gitops=true do_export_html=false github_token=XXX"
   ```

3. **ArgoCD sincroniza automáticamente** las políticas a los clusters etiquetados

4. **Exportar reportes** de todos los clusters:
   ```bash
   ./scripts/ejecutar-playbook-hub.sh \
     -e "do_gitops=false do_export_html=true" \
     cluster-acs cluster-2
   ```

## ❓ Preguntas Frecuentes

### ¿Cómo quito un cluster de la auditoría?

Simplemente quita la etiqueta:

```bash
oc label managedcluster <nombre-cluster> compliance-
```

### ¿Puedo usar múltiples etiquetas?

Sí, puedes combinar etiquetas usando `matchExpressions` con operadores `In`:

```yaml
matchExpressions:
  - key: compliance
    operator: In
    values:
      - enabled
  - key: environment
    operator: In
    values:
      - production
      - staging
```

### ¿Qué pasa si un cluster no tiene la etiqueta?

Las políticas simplemente no se aplicarán a ese cluster. No causará errores.

## 📚 Referencias

- [ACM Placement Documentation](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.8/html/governance/governance#placement)
- [Kubernetes Label Selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)

