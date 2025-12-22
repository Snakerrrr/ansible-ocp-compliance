#!/bin/bash
# Script wrapper para ejecutar el playbook desde el HUB (multicluster)
# Configura automáticamente ANSIBLE_ROLES_PATH
# Uso:
#   1. Ejecutar GitOps (aplica a todos los clusters con compliance=enabled):
#      ./scripts/ejecutar-playbook-hub.sh -e "do_gitops=true do_export_html=false github_token=XXX"
#   
#   2. Exportar HTML de clusters específicos:
#      ./scripts/ejecutar-playbook-hub.sh cluster-acs cluster-2 -e "do_gitops=false do_export_html=true"
#   
#   3. Usar clusters por defecto (cluster-acs cluster-2):
#      ./scripts/ejecutar-playbook-hub.sh -e "do_gitops=false do_export_html=true"

set -e

# Obtener directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Exportar ANSIBLE_ROLES_PATH
export ANSIBLE_ROLES_PATH="${PROJECT_ROOT}/roles"

# Lista de clusters por defecto (si no se pasan argumentos)
CLUSTERS_DEFAULT="cluster-acs cluster-2"

# Separar clusters de argumentos de Ansible
CLUSTERS=""
ANSIBLE_ARGS=()
IN_ANSIBLE_ARGS=false
FIRST_ARG_IS_ANSIBLE=false

# Verificar si el primer argumento es una opción de Ansible
if [ $# -gt 0 ] && [[ "$1" =~ ^- ]]; then
  FIRST_ARG_IS_ANSIBLE=true
fi

for arg in "$@"; do
  if [ "$arg" = "--" ]; then
    IN_ANSIBLE_ARGS=true
  elif [ "$IN_ANSIBLE_ARGS" = true ] || [ "$FIRST_ARG_IS_ANSIBLE" = true ]; then
    # Si estamos después de -- o el primer arg es una opción, todo son args de Ansible
    ANSIBLE_ARGS+=("$arg")
  else
    # Si el argumento no empieza con -, asumimos que es un nombre de cluster
    if [[ ! "$arg" =~ ^- ]]; then
      CLUSTERS="$CLUSTERS $arg"
    else
      # Si empieza con -, es un argumento de Ansible
      ANSIBLE_ARGS+=("$arg")
      FIRST_ARG_IS_ANSIBLE=true
    fi
  fi
done

# Detectar si do_export_html está en los argumentos
DO_EXPORT_HTML=false
for arg in "${ANSIBLE_ARGS[@]}"; do
  if [[ "$arg" =~ do_export_html=true ]]; then
    DO_EXPORT_HTML=true
    break
  fi
done

# Si no se especificaron clusters Y no hay argumentos de Ansible al inicio, usar los por defecto
if [ -z "$CLUSTERS" ] && [ "$FIRST_ARG_IS_ANSIBLE" = false ]; then
  CLUSTERS="$CLUSTERS_DEFAULT"
fi

# Limpiar espacios en blanco
CLUSTERS=$(echo "$CLUSTERS" | xargs)

# Si solo hay argumentos de Ansible y no clusters:
# - Si do_export_html=true, iterar sobre clusters por defecto
# - Si no, ejecutar una sola vez sin target_cluster_context (para GitOps)
if [ -z "$CLUSTERS" ] && [ ${#ANSIBLE_ARGS[@]} -gt 0 ]; then
  if [ "$DO_EXPORT_HTML" = true ]; then
    CLUSTERS="$CLUSTERS_DEFAULT"
    echo "ℹ️  do_export_html=true detectado. Iterando sobre clusters por defecto: $CLUSTERS"
  else
    CLUSTERS="__SINGLE_RUN__"
  fi
fi

echo "=========================================="
echo "Ejecutando Compliance Pipeline Multi-Cluster"
echo "=========================================="
echo ""
echo "ANSIBLE_ROLES_PATH: ${ANSIBLE_ROLES_PATH}"
echo "Clusters a procesar: ${CLUSTERS}"
echo "Argumentos adicionales de Ansible: ${ANSIBLE_ARGS[*]}"
echo ""

# Cambiar al directorio del proyecto
cd "${PROJECT_ROOT}"

# Contador de éxitos y fallos
SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_CLUSTERS=()

# Iterar sobre cada cluster
for CONTEXT in $CLUSTERS; do
  if [ "$CONTEXT" = "__SINGLE_RUN__" ]; then
    echo "=========================================="
    echo "👉 Ejecutando Playbook (sin cluster específico)"
    echo "=========================================="
    
    # Ejecutar el playbook sin target_cluster_context (para GitOps que aplica a todos)
    if ansible-playbook playbooks/compliance-pipeline.yml \
      -i inventories/localhost.yml \
      "${ANSIBLE_ARGS[@]}"; then
      echo ""
      echo "✅ Ejecución exitosa"
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
      echo ""
      echo "❌ Error en la ejecución"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  else
    echo "=========================================="
    echo "👉 Procesando Cluster: $CONTEXT"
    echo "=========================================="
    
    # Ejecutar el playbook pasando el contexto actual
    if ansible-playbook playbooks/compliance-pipeline.yml \
      -i inventories/localhost.yml \
      -e "target_cluster_context=$CONTEXT" \
      "${ANSIBLE_ARGS[@]}"; then
      echo ""
      echo "✅ Extracción exitosa para $CONTEXT"
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
      echo ""
      echo "❌ Error extrayendo datos de $CONTEXT. Continuando con el siguiente..."
      FAIL_COUNT=$((FAIL_COUNT + 1))
      FAILED_CLUSTERS+=("$CONTEXT")
    fi
  fi
  echo ""
done

echo "=========================================="
echo "🏁 Proceso multi-cluster finalizado"
echo "=========================================="
echo "✅ Clusters exitosos: $SUCCESS_COUNT"
echo "❌ Clusters con errores: $FAIL_COUNT"
if [ $FAIL_COUNT -gt 0 ]; then
  echo "   Clusters fallidos: ${FAILED_CLUSTERS[*]}"
fi
echo ""
echo "📂 Los reportes están organizados por cluster en:"
echo "   /tmp/compliance-reports/<cluster-name>/"
echo ""

# Salir con código de error si hubo fallos
if [ $FAIL_COUNT -gt 0 ]; then
  exit 1
fi

