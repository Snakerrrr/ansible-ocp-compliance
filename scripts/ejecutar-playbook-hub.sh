#!/bin/bash
# Script wrapper para ejecutar el playbook desde el HUB
# Configura automáticamente ANSIBLE_ROLES_PATH

set -e

# Obtener directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Exportar ANSIBLE_ROLES_PATH
export ANSIBLE_ROLES_PATH="${PROJECT_ROOT}/roles"

echo "=========================================="
echo "Ejecutando Compliance Pipeline desde HUB"
echo "=========================================="
echo ""
echo "ANSIBLE_ROLES_PATH: ${ANSIBLE_ROLES_PATH}"
echo ""

# Cambiar al directorio del proyecto
cd "${PROJECT_ROOT}"

# Ejecutar el playbook con todos los argumentos pasados
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  "$@"

