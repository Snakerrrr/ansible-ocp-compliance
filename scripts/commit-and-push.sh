#!/bin/bash
# Script para hacer commit y push rápido de cambios
# Uso: ./scripts/commit-and-push.sh "mensaje del commit"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "${PROJECT_ROOT}"

# Mensaje del commit (por defecto usa timestamp)
COMMIT_MSG="${1:-Actualización automática $(date +%Y-%m-%d_%H:%M:%S)}"

echo "=========================================="
echo "Commit y Push para AAP"
echo "=========================================="
echo ""

# Verificar estado de git
echo "📊 Estado actual del repositorio:"
git status --short
echo ""

# Agregar todos los cambios
echo "➕ Agregando cambios..."
git add .
echo ""

# Hacer commit
echo "💾 Haciendo commit: $COMMIT_MSG"
git commit -m "$COMMIT_MSG" || {
    echo "⚠️  No hay cambios para commitear"
    exit 0
}
echo ""

# Hacer push
echo "🚀 Haciendo push a remoto..."
git push
echo ""

echo "✅ Cambios enviados a Git. AAP debería sincronizar automáticamente."
echo ""
echo "ℹ️  Si AAP no sincroniza automáticamente, ve a Projects > Tu Proyecto > Sync"
echo ""

