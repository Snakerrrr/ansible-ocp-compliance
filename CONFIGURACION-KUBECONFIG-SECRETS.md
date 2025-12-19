# Configuración de Kubeconfigs usando Secrets (Recomendado)

Este documento explica cómo configurar los kubeconfigs de los managed clusters usando **Secrets en el Hub**, que es más seguro que mantener archivos en el bastión.

## ¿Por qué usar Secrets?

✅ **Más seguro**: Los kubeconfigs no quedan en archivos del sistema de archivos  
✅ **Centralizado**: Todos los kubeconfigs están en el Hub, fácil de gestionar  
✅ **RBAC**: Puedes controlar quién puede acceder a los secrets  
✅ **Auditable**: Los accesos a secrets se registran en los logs del cluster  
✅ **Sin archivos temporales**: No necesitas mantener archivos en `/tmp`

## Arquitectura

```
Hub Cluster
├── Namespace: openshift-compliance (o personalizado)
│   ├── Secret: managed-cluster-kubeconfig-cluster-acs
│   ├── Secret: managed-cluster-kubeconfig-cluster-2
│   └── Secret: managed-cluster-kubeconfig-cluster-3
└── Playbook Ansible
    └── Extrae kubeconfig desde secret automáticamente
```

## Configuración Inicial

### Paso 1: Obtener Kubeconfig del Managed Cluster

Primero, necesitas obtener el kubeconfig del managed cluster:

```bash
# Opción A: Desde el managed cluster directamente
oc login <api-server-url-del-managed-cluster>
oc config view --minify --raw > /tmp/kubeconfig-cluster-acs

# Opción B: Usar ServiceAccount con token de larga duración (recomendado)
# Ver SOLUCION-EXPIRACION-KUBECONFIG.md para detalles
```

### Paso 2: Crear Secret en el Hub

Usa el script proporcionado para crear el secret:

```bash
# Desde el Hub, crear secret desde archivo existente
./scripts/crear-secret-kubeconfig.sh cluster-acs /tmp/kubeconfig-cluster-acs

# O si el kubeconfig está en la ubicación por defecto
./scripts/crear-secret-kubeconfig.sh cluster-acs
```

El script:
1. Lee el kubeconfig desde el archivo especificado (o ubicación por defecto)
2. Crea/actualiza el secret `managed-cluster-kubeconfig-{cluster-name}` en el namespace `openshift-compliance`
3. Verifica que el secret se creó correctamente

### Paso 3: Verificar el Secret

```bash
# Verificar que el secret existe
oc get secret managed-cluster-kubeconfig-cluster-acs -n openshift-compliance

# Ver el tamaño del secret
oc get secret managed-cluster-kubeconfig-cluster-acs -n openshift-compliance -o jsonpath='{.data.kubeconfig}' | wc -c
```

## Uso en el Playbook

Una vez creado el secret, el playbook lo detectará automáticamente:

```bash
./scripts/ejecutar-playbook-hub.sh \
  -e "github_token=XXX do_gitops=true do_export_html=true \
      placement_label_key=environment \
      placement_label_value=cluster-acs \
      target_cluster_context=cluster-acs"
```

**No necesitas especificar nada adicional** - el playbook busca automáticamente el secret.

## Orden de Búsqueda del Playbook

El playbook busca el kubeconfig en este orden:

1. **Secret en el Hub** (prioridad más alta)
   - Namespace: `openshift-compliance` (o el especificado en `kubeconfig_secret_namespace`)
   - Nombre: `managed-cluster-kubeconfig-{target_cluster_context}`
   
2. **Variable `managed_cluster_kubeconfigs`** (fallback)
   - Diccionario con rutas a archivos locales
   
3. **Archivo en ubicación por defecto** (fallback)
   - `/tmp/kubeconfig-{target_cluster_context}`

## Múltiples Clusters

Para configurar múltiples clusters, crea un secret por cada uno:

```bash
# Cluster 1
./scripts/crear-secret-kubeconfig.sh cluster-acs /tmp/kubeconfig-cluster-acs

# Cluster 2
./scripts/crear-secret-kubeconfig.sh cluster-2 /tmp/kubeconfig-cluster-2

# Cluster 3
./scripts/crear-secret-kubeconfig.sh cluster-3 /tmp/kubeconfig-cluster-3
```

Luego ejecuta el playbook especificando el cluster objetivo:

```bash
# Exportar desde cluster-acs
./scripts/ejecutar-playbook-hub.sh \
  -e "do_export_html=true target_cluster_context=cluster-acs"

# Exportar desde cluster-2
./scripts/ejecutar-playbook-hub.sh \
  -e "do_export_html=true target_cluster_context=cluster-2"
```

## Actualizar Kubeconfig (cuando expira)

Cuando el token del kubeconfig expire, simplemente actualiza el secret:

```bash
# 1. Obtener nuevo kubeconfig
oc login <api-server-url>
oc config view --minify --raw > /tmp/kubeconfig-cluster-acs

# 2. Actualizar secret (el script actualiza si ya existe)
./scripts/crear-secret-kubeconfig.sh cluster-acs /tmp/kubeconfig-cluster-acs
```

O si usas ServiceAccount con token de larga duración:

```bash
# Renovar token del ServiceAccount
TOKEN=$(oc create token compliance-exporter -n openshift-compliance --duration=8760h)

# Actualizar kubeconfig local
# ... (ver SOLUCION-EXPIRACION-KUBECONFIG.md)

# Actualizar secret
./scripts/crear-secret-kubeconfig.sh cluster-acs /tmp/kubeconfig-cluster-acs
```

## Namespace Personalizado

Si prefieres usar un namespace diferente:

```bash
# Crear secret en namespace personalizado
./scripts/crear-secret-kubeconfig.sh cluster-acs /tmp/kubeconfig-cluster-acs compliance-kubeconfigs

# Especificar namespace en el playbook
./scripts/ejecutar-playbook-hub.sh \
  -e "do_export_html=true target_cluster_context=cluster-acs \
      kubeconfig_secret_namespace=compliance-kubeconfigs"
```

## Seguridad y RBAC

### Controlar Acceso a los Secrets

Puedes usar RBAC de OpenShift para controlar quién puede acceder a los secrets:

```bash
# Crear Role para leer secrets de kubeconfig
cat <<EOF | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: compliance-kubeconfig-reader
  namespace: openshift-compliance
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["managed-cluster-kubeconfig-*"]
  verbs: ["get", "list"]
EOF

# Otorgar role a un usuario o ServiceAccount
oc adm policy add-role-to-user compliance-kubeconfig-reader <usuario> -n openshift-compliance
```

### Rotación de Secrets

Para mayor seguridad, considera rotar los secrets periódicamente:

```bash
# Script de ejemplo para rotación automática
#!/bin/bash
for cluster in cluster-acs cluster-2 cluster-3; do
    # Verificar si el token está próximo a expirar
    # Si es así, renovar y actualizar secret
    ./scripts/crear-secret-kubeconfig.sh ${cluster}
done
```

## Troubleshooting

### Error: "No se encontró kubeconfig para el managed cluster"

**Causa**: El secret no existe en el Hub.

**Solución**:
```bash
# Verificar que el secret existe
oc get secret managed-cluster-kubeconfig-cluster-acs -n openshift-compliance

# Si no existe, crearlo
./scripts/crear-secret-kubeconfig.sh cluster-acs
```

### Error: "Unauthorized" al acceder al secret

**Causa**: El usuario no tiene permisos para leer el secret.

**Solución**:
```bash
# Verificar permisos
oc auth can-i get secrets/managed-cluster-kubeconfig-cluster-acs -n openshift-compliance

# Otorgar permisos si es necesario
oc adm policy add-role-to-user view $(oc whoami) -n openshift-compliance
```

### Error: "Secret está vacío o inválido"

**Causa**: El contenido del secret no es un kubeconfig válido.

**Solución**:
```bash
# Verificar contenido del secret
oc get secret managed-cluster-kubeconfig-cluster-acs -n openshift-compliance -o jsonpath='{.data.kubeconfig}' | base64 -d | head -5

# Si está vacío o inválido, recrear
./scripts/crear-secret-kubeconfig.sh cluster-acs /tmp/kubeconfig-cluster-acs
```

## Migración desde Archivos Locales

Si ya tienes kubeconfigs en archivos locales, migra a secrets:

```bash
# Para cada cluster
for cluster in cluster-acs cluster-2 cluster-3; do
    if [ -f "/tmp/kubeconfig-${cluster}" ]; then
        echo "Migrando ${cluster}..."
        ./scripts/crear-secret-kubeconfig.sh ${cluster} /tmp/kubeconfig-${cluster}
        echo "✅ ${cluster} migrado"
    fi
done

# Una vez migrado, puedes eliminar los archivos locales (opcional)
# rm /tmp/kubeconfig-*
```

## Ventajas vs Archivos Locales

| Aspecto | Secrets | Archivos Locales |
|---------|---------|------------------|
| Seguridad | ✅ En el cluster con RBAC | ❌ En sistema de archivos |
| Persistencia | ✅ Persiste en el cluster | ❌ Se pierde al reiniciar |
| Auditoría | ✅ Logs de acceso | ❌ No hay auditoría |
| Multi-usuario | ✅ Compartido en el cluster | ❌ Solo en el bastión |
| Rotación | ✅ Fácil de actualizar | ❌ Manual en cada bastión |

