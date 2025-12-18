#!/bin/bash
# Script de prueba para validar el playbook corregido

set -e

echo "=========================================="
echo "Prueba del Playbook Compliance Pipeline"
echo "=========================================="
echo ""

# Verificar que estamos en el directorio correcto
if [ ! -f "playbooks/compliance-pipeline.yml" ]; then
    echo "❌ ERROR: No se encuentra playbooks/compliance-pipeline.yml"
    echo "   Asegúrate de estar en el directorio ansible-ocp-compliance"
    exit 1
fi

echo "✅ Playbook encontrado"
echo ""

# Verificar sintaxis del playbook
echo "1. Verificando sintaxis del playbook..."
ansible-playbook playbooks/compliance-pipeline.yml -i inventories/localhost.yml --syntax-check
if [ $? -eq 0 ]; then
    echo "✅ Sintaxis correcta"
else
    echo "❌ Error de sintaxis"
    exit 1
fi
echo ""

# Ejecutar en modo dry-run (check mode)
echo "2. Ejecutando en modo dry-run (check mode)..."
echo "   (Esto no hará cambios reales, solo validará la ejecución)"
echo ""

ansible-playbook playbooks/compliance-pipeline.yml \
  -i inventories/localhost.yml \
  -e "github_token=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 \
      do_gitops=true \
      do_export_html=false \
      run_cis=true \
      run_pci=true \
      scan_remediation_action=inform" \
  --check

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Playbook validado correctamente en modo check"
    echo ""
    echo "=========================================="
    echo "Para ejecutar realmente (sin --check):"
    echo "=========================================="
    echo ""
    echo "ansible-playbook playbooks/compliance-pipeline.yml \\"
    echo "  -i inventories/localhost.yml \\"
    echo "  -e 'github_token=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 do_gitops=true do_export_html=false run_cis=true run_pci=true scan_remediation_action=inform'"
    echo ""
else
    echo ""
    echo "❌ Error en la ejecución del playbook"
    exit 1
fi

