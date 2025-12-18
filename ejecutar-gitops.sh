#!/bin/bash
# Script para ejecutar el playbook de GitOps correctamente

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================="
echo "Ejecución del Playbook Compliance Pipeline"
echo "==========================================${NC}"
echo ""

# Verificar que estamos en el directorio correcto
if [ ! -f "ansible.cfg" ]; then
    echo -e "${RED}❌ ERROR: No se encuentra ansible.cfg${NC}"
    echo "   Asegúrate de estar en el directorio ansible-ocp-compliance"
    exit 1
fi

if [ ! -f "playbooks/compliance-pipeline.yml" ]; then
    echo -e "${RED}❌ ERROR: No se encuentra playbooks/compliance-pipeline.yml${NC}"
    exit 1
fi

# Verificar que los roles existen
echo -e "${YELLOW}Verificando roles...${NC}"
for role in gitops_policy_update toggle_policies compliance_export_html; do
    if [ ! -d "roles/$role" ]; then
        echo -e "${RED}❌ Rol faltante: $role${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✅ Todos los roles encontrados${NC}"
echo ""

# Verificar configuración de Ansible
echo -e "${YELLOW}Verificando configuración de Ansible...${NC}"
ROLES_PATH=$(ansible-config dump | grep "^DEFAULT_ROLES_PATH" | cut -d'=' -f2 | tr -d ' ' || echo "")
if [ -z "$ROLES_PATH" ]; then
    echo -e "${YELLOW}⚠️  No se puede obtener ROLES_PATH desde ansible-config${NC}"
    echo "   Usando: roles (desde ansible.cfg)"
else
    echo -e "${GREEN}✅ ROLES_PATH: $ROLES_PATH${NC}"
fi
echo ""

# Establecer variable de entorno para asegurar que se use la ruta correcta
export ANSIBLE_ROLES_PATH="$(pwd)/roles:$ANSIBLE_ROLES_PATH"

echo -e "${GREEN}Ejecutando playbook...${NC}"
echo ""

# Ejecutar el playbook
ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "github_token=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 \
      do_gitops=true \
      do_export_html=false \
      run_cis=true \
      run_pci=true \
      scan_remediation_action=inform"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=========================================="
    echo "✅ Playbook ejecutado exitosamente"
    echo "==========================================${NC}"
    echo ""
    echo "Próximos pasos:"
    echo "  1. Verificar commit en GitHub (repo acm-policies)"
    echo "  2. Esperar 5-10 minutos para que ArgoCD sincronice"
    echo "  3. Verificar políticas en ACM Hub"
    echo "  4. Verificar scans en cluster-acs"
else
    echo ""
    echo -e "${RED}=========================================="
    echo "❌ Error en la ejecución del playbook"
    echo "==========================================${NC}"
    exit 1
fi

