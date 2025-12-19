# Solución al Problema de Expiración de Kubeconfig

## Problema

Los kubeconfigs contienen tokens que expiran típicamente después de 24 horas. Esto puede causar que el playbook falle si el kubeconfig está expirado.

## Solución Recomendada: ServiceAccount con Token de Larga Duración

Para evitar expiraciones frecuentes en producción, crea un ServiceAccount con un token de larga duración (1 año o más).

### Paso 1: Crear ServiceAccount en el Managed Cluster

```bash
# Loguearte al managed cluster
oc login <api-server-url-del-managed-cluster>

# Crear ServiceAccount
oc create serviceaccount compliance-exporter -n openshift-compliance
```

### Paso 2: Otorgar Permisos Necesarios

El ServiceAccount necesita permisos para leer PVCs en el namespace `openshift-compliance`:

```bash
# Opción A: Cluster-reader (permite leer recursos en todo el cluster, incluyendo PVCs)
oc adm policy add-cluster-role-to-user cluster-reader system:serviceaccount:openshift-compliance:compliance-exporter

# Opción B: Permisos específicos (más restrictivo)
oc adm policy add-role-to-user view system:serviceaccount:openshift-compliance:compliance-exporter -n openshift-compliance
```

### Paso 3: Obtener Token de Larga Duración

```bash
# Crear token válido por 1 año (8760 horas)
TOKEN=$(oc create token compliance-exporter -n openshift-compliance --duration=8760h)

# Verificar que el token se obtuvo
echo "Token obtenido: ${TOKEN:0:20}..."
```

### Paso 4: Obtener API Server URL

```bash
# Obtener URL del API server del managed cluster
API_SERVER=$(oc config view --minify -o jsonpath='{.clusters[0].cluster.server}')
echo "API Server: ${API_SERVER}"
```

### Paso 5: Crear Kubeconfig con Token del ServiceAccount

```bash
CLUSTER_NAME="cluster-acs"  # Cambiar por el nombre de tu cluster
KUBECONFIG_PATH="/tmp/kubeconfig-${CLUSTER_NAME}"

cat > ${KUBECONFIG_PATH} <<EOF
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

# Ajustar permisos
chmod 600 ${KUBECONFIG_PATH}

echo "✅ Kubeconfig creado en: ${KUBECONFIG_PATH}"
```

### Paso 6: Verificar que Funciona

```bash
# Probar acceso al cluster usando el nuevo kubeconfig
KUBECONFIG=${KUBECONFIG_PATH} oc get nodes

# Probar acceso a PVCs
KUBECONFIG=${KUBECONFIG_PATH} oc get pvc -n openshift-compliance
```

### Paso 7: Usar en el Playbook

```bash
./scripts/ejecutar-playbook-hub.sh \
  -e "github_token=XXX do_gitops=true do_export_html=true \
      placement_label_key=environment \
      placement_label_value=cluster-acs \
      target_cluster_context=cluster-acs"
```

El playbook detectará automáticamente el kubeconfig en `/tmp/kubeconfig-cluster-acs`.

## Ventajas de esta Solución

✅ **Token válido por 1 año** (8760h) o más  
✅ **No requiere renovación frecuente**  
✅ **Ideal para automatización y producción**  
✅ **Permisos mínimos necesarios** (solo lo que necesita)  
✅ **Funciona con múltiples clusters** (crea un ServiceAccount por cluster)

## Renovación del Token

Cuando el token expire (después de 1 año), simplemente renueva el token:

```bash
# Obtener nuevo token
TOKEN=$(oc create token compliance-exporter -n openshift-compliance --duration=8760h)

# Actualizar kubeconfig
sed -i "s/token: .*/token: ${TOKEN}/" /tmp/kubeconfig-${CLUSTER_NAME}
```

## Alternativas

### Opción 1: Renovación Manual

Cuando el token expire, renueva manualmente:

```bash
oc login <api-server-url>
oc config view --minify --raw > /tmp/kubeconfig-{nombre-cluster}
chmod 600 /tmp/kubeconfig-{nombre-cluster}
```

### Opción 2: Script de Renovación

Usa el script `renovar-kubeconfig.sh`:

```bash
./scripts/renovar-kubeconfig.sh cluster-acs
```

### Opción 3: Verificación Automática

El playbook ahora verifica automáticamente si el kubeconfig es válido y muestra una advertencia si está expirado.

## Troubleshooting

### Error: "Unauthorized" o "Forbidden"

**Causa**: El ServiceAccount no tiene permisos suficientes.

**Solución**:
```bash
# Verificar permisos
oc describe serviceaccount compliance-exporter -n openshift-compliance

# Otorgar permisos adicionales si es necesario
oc adm policy add-cluster-role-to-user cluster-reader system:serviceaccount:openshift-compliance:compliance-exporter
```

### Error: "Token expired"

**Causa**: El token del ServiceAccount expiró.

**Solución**:
```bash
# Renovar token
TOKEN=$(oc create token compliance-exporter -n openshift-compliance --duration=8760h)
sed -i "s/token: .*/token: ${TOKEN}/" /tmp/kubeconfig-${CLUSTER_NAME}
```

### Error: "Unable to connect to the server"

**Causa**: El API server URL es incorrecto o el cluster no es accesible.

**Solución**:
1. Verifica que el API server URL sea correcto
2. Verifica conectividad de red
3. Verifica que el cluster esté accesible desde el Hub

