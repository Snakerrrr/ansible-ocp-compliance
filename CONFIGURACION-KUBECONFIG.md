# Configuración de Kubeconfigs para Managed Clusters

> **⚠️ IMPORTANTE**: La forma **recomendada y más segura** es usar **Secrets en el Hub**. Ver [CONFIGURACION-KUBECONFIG-SECRETS.md](CONFIGURACION-KUBECONFIG-SECRETS.md) para detalles.

Este documento explica métodos alternativos para configurar kubeconfigs (archivos locales). Para producción, usa Secrets.

## ¿Por qué necesito configurar kubeconfigs?

Cuando ejecutas el playbook desde el Hub para exportar resultados de compliance desde un managed cluster, necesitas proporcionar el kubeconfig del managed cluster porque:

1. El Hub no tiene acceso directo a los recursos del managed cluster por defecto
2. El secret `admin-kubeconfig` no existe en el namespace del managed cluster en el Hub
3. El token del Hub no tiene permisos para acceder directamente al managed cluster

## Métodos de Configuración

### Método 1: Variable `managed_cluster_kubeconfigs` (Recomendado)

Este método permite configurar múltiples kubeconfigs de una vez, ideal cuando trabajas con varios clusters.

#### Formato

La variable es un diccionario JSON donde:
- **Clave**: Nombre del managed cluster
- **Valor**: Ruta al archivo kubeconfig

```json
{
  "cluster-acs": "/tmp/kubeconfig-cluster-acs",
  "cluster-2": "/tmp/kubeconfig-cluster-2"
}
```

#### Ejemplo de Uso

```bash
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "do_gitops=false do_export_html=true \
      target_cluster_context=cluster-acs \
      managed_cluster_kubeconfigs='{\"cluster-acs\": \"/tmp/kubeconfig-cluster-acs\", \"cluster-2\": \"/tmp/kubeconfig-cluster-2\"}'"
```

### Método 2: Ubicación por Defecto (Un solo cluster)

Si solo trabajas con un cluster, puedes guardar el kubeconfig en la ubicación por defecto:

**Ubicación por defecto**: `/tmp/kubeconfig-{nombre-del-cluster}`

Por ejemplo, para `cluster-acs`:
```bash
cp /ruta/al/kubeconfig /tmp/kubeconfig-cluster-acs
chmod 600 /tmp/kubeconfig-cluster-acs
```

El playbook detectará automáticamente el kubeconfig en esta ubicación.

## Solución al Problema de Expiración

### ⚠️ Problema: Los Tokens Expiran

Los kubeconfigs contienen tokens que expiran típicamente después de 24 horas. Esto puede causar que el playbook falle si el kubeconfig está expirado.

### ✅ Solución Recomendada: ServiceAccount con Token de Larga Duración

Para evitar expiraciones frecuentes en producción, crea un ServiceAccount con un token de larga duración:

```bash
# 1. Crear ServiceAccount en el managed cluster
oc create serviceaccount compliance-exporter -n openshift-compliance

# 2. Dar permisos necesarios (cluster-reader permite leer PVCs)
oc adm policy add-cluster-role-to-user cluster-reader system:serviceaccount:openshift-compliance:compliance-exporter

# 3. Obtener token del ServiceAccount (válido por 1 año)
TOKEN=$(oc create token compliance-exporter -n openshift-compliance --duration=8760h)

# 4. Obtener API server URL
API_SERVER=$(oc config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# 5. Crear kubeconfig con el token del ServiceAccount
CLUSTER_NAME="cluster-acs"
cat > /tmp/kubeconfig-${CLUSTER_NAME} <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: ${API_SERVER}
    insecure-skip-tls-verify: true
  name: ${CLUSTER_NAME}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: compliance-exporter
  name: ${CLUSTER_NAME}
current-context: ${CLUSTER_NAME}
users:
- name: compliance-exporter
  user:
    token: ${TOKEN}
EOF
chmod 600 /tmp/kubeconfig-${CLUSTER_NAME}
```

**Ventajas**:
- ✅ Token válido por 1 año (8760h) o más
- ✅ No requiere renovación frecuente
- ✅ Ideal para automatización y producción
- ✅ Permisos mínimos necesarios (cluster-reader)

### Alternativa: Renovación Manual o Automática

Si prefieres usar tokens de usuario normales:

1. **Renovación Manual**: Cuando expire, renueva manualmente
2. **Script de Renovación**: Usa `./scripts/renovar-kubeconfig.sh cluster-acs`
3. **Verificación Automática**: El playbook ahora verifica automáticamente si el kubeconfig es válido

## Cómo Obtener el Kubeconfig del Managed Cluster

### Opción 1: Desde el Managed Cluster (Recomendado)

Si tienes acceso directo al managed cluster:

```bash
# 1. Loguearte al managed cluster
oc login <api-server-url-del-managed-cluster>

# 2. Exportar el kubeconfig actual
oc config view --minify --raw > /tmp/kubeconfig-{nombre-cluster}
chmod 600 /tmp/kubeconfig-{nombre-cluster}
```

### Opción 2: Usar el Script Automático

```bash
# Desde WSL, en el directorio del proyecto
./scripts/obtener-kubeconfig-managed-cluster.sh cluster-acs
```

El script intentará:
1. Buscar el secret `admin-kubeconfig` en el namespace del cluster
2. Obtener la URL del API server del managed cluster
3. Crear un kubeconfig temporal usando el token del Hub (puede que no funcione por permisos)

### Opción 3: Desde el Secret hub-kubeconfig-secret

Si el secret `hub-kubeconfig-secret` existe en el managed cluster:

```bash
# Desde el managed cluster
oc get secret hub-kubeconfig-secret -n <namespace> -o jsonpath='{.data.kubeconfig}' | base64 -d > /tmp/kubeconfig-{nombre-cluster}
chmod 600 /tmp/kubeconfig-{nombre-cluster}
```

## Ejemplos Completos

### Ejemplo 1: Un solo cluster (cluster-acs)

```bash
# 1. Obtener kubeconfig
oc login <api-server-cluster-acs>
oc config view --minify --raw > /tmp/kubeconfig-cluster-acs
chmod 600 /tmp/kubeconfig-cluster-acs

# 2. Ejecutar playbook (detecta automáticamente)
export ANSIBLE_ROLES_PATH=$(pwd)/roles
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "github_token=XXX do_gitops=true do_export_html=true \
      placement_label_key=environment \
      placement_label_value=cluster-acs \
      target_cluster_context=cluster-acs"
```

### Ejemplo 2: Múltiples clusters

```bash
# 1. Obtener kubeconfigs de todos los clusters
oc login <api-server-cluster-acs>
oc config view --minify --raw > /tmp/kubeconfig-cluster-acs
chmod 600 /tmp/kubeconfig-cluster-acs

oc login <api-server-cluster-2>
oc config view --minify --raw > /tmp/kubeconfig-cluster-2
chmod 600 /tmp/kubeconfig-cluster-2

# 2. Ejecutar playbook especificando todos los kubeconfigs
export ANSIBLE_ROLES_PATH=$(pwd)/roles
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "github_token=XXX do_gitops=true do_export_html=true \
      placement_label_key=environment \
      placement_label_value=cluster-acs \
      target_cluster_context=cluster-acs \
      managed_cluster_kubeconfigs='{\"cluster-acs\": \"/tmp/kubeconfig-cluster-acs\", \"cluster-2\": \"/tmp/kubeconfig-cluster-2\"}'"
```

### Ejemplo 3: Cambiar entre clusters

Para exportar desde `cluster-2` en lugar de `cluster-acs`:

```bash
export ANSIBLE_ROLES_PATH=$(pwd)/roles
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "do_gitops=false do_export_html=true \
      target_cluster_context=cluster-2 \
      managed_cluster_kubeconfigs='{\"cluster-acs\": \"/tmp/kubeconfig-cluster-acs\", \"cluster-2\": \"/tmp/kubeconfig-cluster-2\"}'"
```

## Verificación

Para verificar que el kubeconfig está correctamente configurado:

```bash
# Verificar que el archivo existe
ls -lh /tmp/kubeconfig-cluster-acs

# Verificar que el contenido es válido
head -5 /tmp/kubeconfig-cluster-acs

# Probar acceso al cluster usando el kubeconfig
KUBECONFIG=/tmp/kubeconfig-cluster-acs oc get nodes
```

## Manejo de Expiración de Tokens

### Problema

Los tokens en los kubeconfigs expiran después de un tiempo (típicamente 24 horas). Esto puede causar que el playbook falle si el kubeconfig está expirado.

### Soluciones

#### Opción 1: Renovar Manualmente (Simple)

Cuando el token expire, renueva el kubeconfig:

```bash
# 1. Loguearte al managed cluster
oc login <api-server-url>

# 2. Exportar nuevo kubeconfig
oc config view --minify --raw > /tmp/kubeconfig-{nombre-cluster}
chmod 600 /tmp/kubeconfig-{nombre-cluster}
```

#### Opción 2: Usar Script de Renovación

```bash
# Verificar y renovar si es necesario
./scripts/renovar-kubeconfig.sh cluster-acs
```

#### Opción 3: ServiceAccount con Token de Larga Duración (Recomendado para Producción)

Para evitar expiraciones frecuentes, crea un ServiceAccount con un token de larga duración:

```bash
# 1. Crear ServiceAccount en el managed cluster
oc create serviceaccount compliance-exporter -n openshift-compliance

# 2. Dar permisos necesarios
oc adm policy add-cluster-role-to-user cluster-reader system:serviceaccount:openshift-compliance:compliance-exporter

# 3. Obtener token del ServiceAccount
TOKEN=$(oc create token compliance-exporter -n openshift-compliance --duration=8760h)

# 4. Crear kubeconfig con el token del ServiceAccount
API_SERVER=$(oc config view --minify -o jsonpath='{.clusters[0].cluster.server}')
cat > /tmp/kubeconfig-{nombre-cluster} <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: ${API_SERVER}
    insecure-skip-tls-verify: true
  name: {nombre-cluster}
contexts:
- context:
    cluster: {nombre-cluster}
    user: compliance-exporter
  name: {nombre-cluster}
current-context: {nombre-cluster}
users:
- name: compliance-exporter
  user:
    token: ${TOKEN}
EOF
chmod 600 /tmp/kubeconfig-{nombre-cluster}
```

**Ventajas**:
- Token válido por 1 año (8760h) o más
- No requiere renovación frecuente
- Ideal para automatización

#### Opción 4: Renovación Automática en el Playbook

El playbook ahora verifica automáticamente si el kubeconfig es válido y muestra una advertencia si está expirado.

## Troubleshooting

### Error: "No se encontró kubeconfig para el managed cluster"

**Causa**: El kubeconfig no está en la ubicación esperada.

**Solución**:
1. Verifica que el archivo existe: `ls -lh /tmp/kubeconfig-{nombre-cluster}`
2. Si usas `managed_cluster_kubeconfigs`, verifica que el nombre del cluster coincida exactamente
3. Verifica los permisos: `chmod 600 /tmp/kubeconfig-{nombre-cluster}`

### Error: "Unable to connect to the server" o "Unauthorized"

**Causa**: El kubeconfig está expirado o es inválido.

**Solución**:
1. Verifica la validez: `KUBECONFIG=/tmp/kubeconfig-{nombre-cluster} oc whoami`
2. Si falla, renueva el kubeconfig usando una de las opciones anteriores
3. Para producción, usa ServiceAccount con token de larga duración

### Error: "Forbidden"

**Causa**: El usuario del kubeconfig no tiene permisos suficientes.

**Solución**:
1. Verifica que el usuario tenga permisos para acceder a PVCs en `openshift-compliance`
2. Obtén un kubeconfig con un usuario con más permisos (ej: admin o ServiceAccount con cluster-reader)

