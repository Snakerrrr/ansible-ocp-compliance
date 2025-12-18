#!/bin/bash
# Script para mover reportes de compliance desde /tmp a una ubicación accesible
# Uso: ./scripts/mover-reportes.sh [destino]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SOURCE_DIR="/tmp/compliance-reports"
DEST_DIR="${1:-$PROJECT_ROOT/compliance-reports}"

echo "=========================================="
echo "Mover Reportes de Compliance"
echo "=========================================="
echo ""

# Verificar que existe el directorio fuente
if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ ERROR: No se encuentra el directorio fuente: $SOURCE_DIR"
    echo "   Ejecuta primero el playbook de export HTML"
    exit 1
fi

# Mostrar contenido actual
echo "Contenido en $SOURCE_DIR:"
ls -lh "$SOURCE_DIR" | head -15
echo ""

# Crear directorio destino si no existe
mkdir -p "$DEST_DIR"

# Copiar archivos
echo "Copiando reportes a: $DEST_DIR"
cp -r "$SOURCE_DIR"/* "$DEST_DIR/"

# Verificar que se copió correctamente
if [ $? -eq 0 ]; then
    echo "✅ Reportes copiados exitosamente"
    echo ""
    echo "Ubicación de los reportes:"
    echo "  $DEST_DIR"
    echo ""
    echo "Contenido copiado:"
    ls -lh "$DEST_DIR" | head -15
    echo ""
    
    # Contar archivos HTML
    HTML_COUNT=$(find "$DEST_DIR" -name "*.html" -type f 2>/dev/null | wc -l)
    if [ "$HTML_COUNT" -gt 0 ]; then
        echo "✅ Encontrados $HTML_COUNT archivo(s) HTML"
        echo ""
        echo "Para visualizar los reportes HTML:"
        echo "  1. Abre el navegador"
        echo "  2. Navega a: file://$DEST_DIR/[nombre-del-pvc]/[archivo].html"
        echo ""
        echo "O desde WSL:"
        echo "  explorer.exe $(wslpath -w "$DEST_DIR")"
    else
        echo "⚠️  No se encontraron archivos HTML. Los datos pueden estar solo en XML."
    fi
    
    # Mostrar ubicación del ZIP
    ZIP_FILE=$(find "$DEST_DIR" -name "compliance-reports-*.zip" -type f | head -1)
    if [ -n "$ZIP_FILE" ]; then
        echo ""
        echo "📦 Archivo ZIP disponible:"
        echo "  $ZIP_FILE"
        echo ""
        echo "Para extraer el ZIP:"
        echo "  unzip '$ZIP_FILE' -d '$DEST_DIR/extracted'"
    fi
else
    echo "❌ Error al copiar los archivos"
    exit 1
fi

echo ""
echo "=========================================="

