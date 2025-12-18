#!/bin/bash
# Script para verificar la configuración de Ansible

echo "=========================================="
echo "Verificación de Configuración Ansible"
echo "=========================================="
echo ""

# Verificar que estamos en el directorio correcto
if [ ! -f "ansible.cfg" ]; then
    echo "❌ ERROR: No se encuentra ansible.cfg"
    echo "   Asegúrate de estar en el directorio ansible-ocp-compliance"
    exit 1
fi

echo "✅ ansible.cfg encontrado"
echo ""

# Mostrar contenido de ansible.cfg
echo "Contenido de ansible.cfg:"
cat ansible.cfg
echo ""

# Verificar estructura de directorios
echo "Estructura de directorios:"
echo "  - roles/"
if [ -d "roles" ]; then
    echo "    ✅ Existe"
    echo "    Roles encontrados:"
    ls -1 roles/ | sed 's/^/      - /'
else
    echo "    ❌ No existe"
fi
echo ""

# Verificar roles específicos
echo "Verificando roles requeridos:"
for role in gitops_policy_update toggle_policies compliance_export_html; do
    if [ -d "roles/$role" ]; then
        echo "  ✅ $role"
    else
        echo "  ❌ $role (FALTA)"
    fi
done
echo ""

# Verificar configuración de Ansible
echo "Configuración de Ansible (ansible-config dump):"
ansible-config dump | grep -E "(roles_path|inventory)" || echo "  (No se puede obtener configuración)"
echo ""

# Probar búsqueda de roles
echo "Probando búsqueda de roles con ansible-galaxy:"
ansible-galaxy list 2>&1 | head -20 || echo "  (No se pueden listar roles)"
echo ""

echo "=========================================="
echo "Para ejecutar el playbook:"
echo "=========================================="
echo ""
echo "ansible-playbook playbooks/compliance-pipeline.yml \\"
echo "  -i inventories/localhost.yml \\"
echo "  -e 'github_token=XXX do_gitops=true do_export_html=false'"
echo ""

