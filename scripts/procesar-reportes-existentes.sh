#!/bin/bash
# Script para procesar reportes XML comprimidos (.bzip2) y convertirlos a HTML
# Uso: ./scripts/procesar-reportes-existentes.sh [directorio]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPORTS_DIR="${1:-$PROJECT_ROOT/compliance-reports}"

echo "=========================================="
echo "Procesar Reportes Existentes"
echo "=========================================="
echo ""

# Verificar que existe el directorio
if [ ! -d "$REPORTS_DIR" ]; then
    echo "❌ ERROR: No se encuentra el directorio: $REPORTS_DIR"
    exit 1
fi

echo "Procesando reportes en: $REPORTS_DIR"
echo ""

# Verificar herramientas necesarias
if ! command -v bunzip2 &> /dev/null && ! command -v bzip2 &> /dev/null; then
    echo "❌ ERROR: bunzip2 o bzip2 no están disponibles"
    echo "   Instala con: sudo apt-get install bzip2"
    exit 1
fi

if ! command -v oscap &> /dev/null; then
    echo "❌ ERROR: oscap no está disponible"
    echo "   Instala con: sudo apt-get install openscap-scanner"
    exit 1
fi

# Crear script temporal de procesamiento
TEMP_SCRIPT="/tmp/render_reports_$$.sh"
cat > "$TEMP_SCRIPT" << 'SCRIPT_EOF'
#!/bin/bash
OUTPUT_DIR="$1"

echo "Paso 1: Procesando archivos .bzip2..."
# Primero, verificar si hay archivos .bzip2.out (ya descomprimidos)
OUT_COUNT=$(find "$OUTPUT_DIR" -name "*.bzip2.out" -type f 2>/dev/null | wc -l)
if [ "$OUT_COUNT" -gt 0 ]; then
    echo "Encontrados $OUT_COUNT archivo(s) .bzip2.out (ya descomprimidos)"
    find "$OUTPUT_DIR" -name "*.bzip2.out" -type f | while read out_file; do
        # Convertir archivo.xml.bzip2.out → archivo.xml (sin agregar .xml extra)
        xml_file="${out_file%.bzip2.out}"
        if [ ! -f "$xml_file" ]; then
            if cp "$out_file" "$xml_file" 2>/dev/null; then
                echo "  ✅ Copiado: $(basename "$out_file") → $(basename "$xml_file")"
            else
                echo "  ❌ Error al copiar: $(basename "$out_file")"
            fi
        else
            echo "  ⏭️  Ya existe: $(basename "$xml_file")"
        fi
    done
    echo ""
fi

# Buscar archivos .bzip2 excluyendo .out y otros archivos temporales
BZIP2_COUNT=$(find "$OUTPUT_DIR" \( -name "*.bzip2" -o -name "*.xml.bzip2" \) -type f ! -name "*.out" ! -name "*.tmp" 2>/dev/null | wc -l)

if [ "$BZIP2_COUNT" -gt 0 ]; then
    echo "Encontrados $BZIP2_COUNT archivo(s) con extensión .bzip2"
    
    find "$OUTPUT_DIR" \( -name "*.bzip2" -o -name "*.xml.bzip2" \) -type f ! -name "*.out" | while read bzip_file; do
        # Determinar nombre del archivo XML de salida
        if [[ "$bzip_file" == *.xml.bzip2 ]]; then
            # Para archivos .xml.bzip2, quitar solo .bzip2
            xml_file="${bzip_file%.bzip2}"
        else
            # Para archivos .bzip2, agregar .xml
            xml_file="${bzip_file%.bzip2}.xml"
        fi
        
        # Verificar si el XML ya existe
        if [ -f "$xml_file" ]; then
            echo "  ⏭️  Ya existe: $(basename "$xml_file")"
            continue
        fi
        
        echo "  Procesando: $(basename "$bzip_file") → $(basename "$xml_file")"
        
        # Verificar el tipo de archivo real
        file_type=$(file -b "$bzip_file" 2>/dev/null || echo "unknown")
        
        # Si el archivo ya es XML (aunque tenga extensión .bzip2), solo copiarlo
        if echo "$file_type" | grep -qi "xml\|text\|ascii"; then
            cp "$bzip_file" "$xml_file" 2>/dev/null && echo "    ✅ Copiado (es XML, no está comprimido)"
        # Si es realmente bzip2, descomprimirlo
        elif echo "$file_type" | grep -qi "bzip2\|compress"; then
            if command -v bunzip2 &> /dev/null; then
                if bunzip2 -k "$bzip_file" 2>/dev/null; then
                    # bunzip2 crea archivo.xml.bzip2 → archivo.xml.bzip2 (sin comprimir)
                    # Necesitamos renombrarlo a archivo.xml
                    if [[ "$bzip_file" == *.xml.bzip2 ]]; then
                        decompressed_file="${bzip_file%.bzip2}"
                        if [ -f "$decompressed_file" ] && [ "$decompressed_file" != "$xml_file" ]; then
                            mv "$decompressed_file" "$xml_file" 2>/dev/null && echo "    ✅ Descomprimido y renombrado a .xml"
                        else
                            echo "    ✅ Descomprimido con bunzip2"
                        fi
                    else
                        echo "    ✅ Descomprimido con bunzip2"
                    fi
                elif bzip2 -dk "$bzip_file" 2>/dev/null; then
                    # Mismo proceso para bzip2
                    if [[ "$bzip_file" == *.xml.bzip2 ]]; then
                        decompressed_file="${bzip_file%.bzip2}"
                        if [ -f "$decompressed_file" ] && [ "$decompressed_file" != "$xml_file" ]; then
                            mv "$decompressed_file" "$xml_file" 2>/dev/null && echo "    ✅ Descomprimido y renombrado a .xml"
                        else
                            echo "    ✅ Descomprimido con bzip2"
                        fi
                    else
                        echo "    ✅ Descomprimido con bzip2"
                    fi
                else
                    echo "    ⚠️  Error al descomprimir"
                fi
            elif command -v bzip2 &> /dev/null; then
                if bzip2 -dk "$bzip_file" 2>/dev/null; then
                    if [[ "$bzip_file" == *.xml.bzip2 ]]; then
                        decompressed_file="${bzip_file%.bzip2}"
                        if [ -f "$decompressed_file" ] && [ "$decompressed_file" != "$xml_file" ]; then
                            mv "$decompressed_file" "$xml_file" 2>/dev/null && echo "    ✅ Descomprimido y renombrado a .xml"
                        else
                            echo "    ✅ Descomprimido con bzip2"
                        fi
                    else
                        echo "    ✅ Descomprimido con bzip2"
                    fi
                else
                    echo "    ⚠️  Error al descomprimir"
                fi
            fi
        # Si no se puede determinar, intentar descomprimir primero, luego copiar si falla
        else
            if command -v bunzip2 &> /dev/null; then
                if bunzip2 -k "$bzip_file" 2>/dev/null; then
                    echo "    ✅ Descomprimido con bunzip2"
                elif bzip2 -dk "$bzip_file" 2>/dev/null; then
                    echo "    ✅ Descomprimido con bzip2"
                else
                    # Si falla la descompresión, intentar copiar directamente
                    if head -1 "$bzip_file" 2>/dev/null | grep -q "<?xml"; then
                        cp "$bzip_file" "$xml_file" 2>/dev/null && echo "    ✅ Copiado directamente (parece XML)"
                    else
                        echo "    ⚠️  No se pudo procesar (tipo desconocido)"
                    fi
                fi
            else
                echo "    ⚠️  bunzip2 no disponible"
            fi
        fi
    done
    echo ""
fi

echo "Paso 2: Convirtiendo archivos XML → HTML..."
XML_COUNT=$(find "$OUTPUT_DIR" -name "*.xml" -type f ! -name "*.bzip2" 2>/dev/null | wc -l)

if [ "$XML_COUNT" -eq 0 ]; then
    echo "⚠️  No se encontraron archivos XML"
    exit 0
fi

echo "Encontrados $XML_COUNT archivo(s) XML para convertir"
echo ""

find "$OUTPUT_DIR" -name "*.xml" -type f ! -name "*.bzip2" | while read xml_file; do
    dir=$(dirname "$xml_file")
    base=$(basename "$xml_file" .xml)
    html_file="$dir/${base}.html"
    
    echo "Convirtiendo: $(basename "$xml_file") → $(basename "$html_file")"
    
    if oscap xccdf generate report "$xml_file" > "$html_file" 2>/dev/null; then
        echo "  ✅ Generado: $(basename "$html_file")"
    else
        echo "  ⚠️  No se pudo convertir con oscap"
    fi
done

echo ""
HTML_COUNT=$(find "$OUTPUT_DIR" -name "*.html" -type f 2>/dev/null | wc -l)
echo "Resumen:"
echo "  - Archivos XML procesados: $XML_COUNT"
echo "  - Archivos HTML generados: $HTML_COUNT"
SCRIPT_EOF

chmod +x "$TEMP_SCRIPT"

# Ejecutar el script
"$TEMP_SCRIPT" "$REPORTS_DIR"

# Limpiar
rm -f "$TEMP_SCRIPT"

echo ""
echo "=========================================="
echo "Procesamiento completado"
echo "=========================================="
echo ""
echo "Para visualizar los reportes HTML:"
echo "  explorer.exe $(wslpath -w "$REPORTS_DIR" 2>/dev/null || echo "$REPORTS_DIR")"
echo ""

