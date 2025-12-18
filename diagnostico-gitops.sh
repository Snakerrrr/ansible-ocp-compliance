#!/bin/bash
# Script de diagnóstico para GitOps

set -e

REPO_PATH="/tmp/acm-policies"
REPO_URL="https://Snakerrrr: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@github.com/Snakerrrr/acm-policies.git"

echo "=========================================="
echo "Diagnóstico GitOps"
echo "=========================================="
echo ""

# Verificar si el repo existe
if [ -d "$REPO_PATH" ]; then
    echo "✅ Repo existe en: $REPO_PATH"
    cd "$REPO_PATH"
    
    echo ""
    echo "Estado actual del repo:"
    echo "----------------------"
    git status
    echo ""
    
    echo "Último commit:"
    echo "-------------"
    git log -1 --oneline
    echo ""
    
    echo "Cambios no commiteados:"
    echo "---------------------"
    git diff --stat
    echo ""
    
    echo "Archivo policy-generator-config.yaml:"
    echo "-------------------------------------"
    if [ -f "base/policy-generator-config.yaml" ]; then
        echo "✅ Archivo existe"
        echo "Última modificación:"
        ls -lh base/policy-generator-config.yaml
        echo ""
        echo "Contenido actual (primeras 20 líneas):"
        head -20 base/policy-generator-config.yaml
    else
        echo "❌ Archivo NO existe"
    fi
    echo ""
    
    echo "Verificar si hay cambios:"
    echo "-----------------------"
    git status --porcelain
    echo ""
    
else
    echo "❌ Repo NO existe en: $REPO_PATH"
    echo "Clonando..."
    git clone "$REPO_URL" "$REPO_PATH"
    cd "$REPO_PATH"
fi

echo "=========================================="

