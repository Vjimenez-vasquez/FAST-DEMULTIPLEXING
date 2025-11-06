

#!/bin/bash

# Configuración
THREADS=22  # Reducido para evitar sobrecarga
OUTPUT_CSV="output_precision_final.csv"

# Header
echo "sample,compressed_bytes,uncompressed_bytes,ratio" > "$OUTPUT_CSV"

# Función robusta y simple
process_sample_robust() {
    local file="$1"
    local prefix=$(basename "$file" .R1.fastq.gz)
    local r1="${prefix}.R1.fastq.gz"
    local r2="${prefix}.R2.fastq.gz"

    echo "Procesando: $prefix" >&2

    # Verificar archivos
    if [[ ! -f "$r1" ]] || [[ ! -f "$r2" ]]; then
        echo "Error: Archivos no encontrados para $prefix" >&2
        return 1
    fi

    # Tamaños comprimidos
    local comp_r1=$(stat -c%s "$r1" 2>/dev/null || echo "0")
    local comp_r2=$(stat -c%s "$r2" 2>/dev/null || echo "0")
    local total_compressed=$((comp_r1 + comp_r2))

    # Tamaños descomprimidos REALES
    local uncomp_r1=0
    local uncomp_r2=0

    # Descomprimir R1 y contar bytes
    if pigz -dc "$r1" 2>/dev/null | wc -c > /tmp/uncomp_r1_$$ 2>/dev/null; then
        uncomp_r1=$(cat /tmp/uncomp_r1_$$)
        rm -f /tmp/uncomp_r1_$$
    fi

    # Descomprimir R2 y contar bytes
    if pigz -dc "$r2" 2>/dev/null | wc -c > /tmp/uncomp_r2_$$ 2>/dev/null; then
        uncomp_r2=$(cat /tmp/uncomp_r2_$$)
        rm -f /tmp/uncomp_r2_$$
    fi

    local total_uncompressed=$((uncomp_r1 + uncomp_r2))

    # Calcular ratio
    local ratio=0
    if [[ $total_uncompressed -gt 0 ]]; then
        ratio=$(echo "scale=6; $total_compressed / $total_uncompressed" | bc -l 2>/dev/null || echo "0")
    fi

    # Output
    printf "%s,%d,%d,%.6f\n" "$prefix" "$total_compressed" "$total_uncompressed" "$ratio"

    echo "Completado: $prefix - Ratio: $ratio" >&2
}

export -f process_sample_robust

echo "Iniciando procesamiento PRECISO Y ROBUSTO..."
echo "Hilos: $THREADS"
echo "Fecha inicio: $(date)"

# Ejecutar
find . -maxdepth 1 -name "*.R1.fastq.gz" | sort | \
parallel --jobs $THREADS \
         --progress \
         --joblog joblog_robust.txt \
         process_sample_robust {} >> "$OUTPUT_CSV"

echo "Fecha fin: $(date)"
echo "¡Procesamiento completado!"
echo "Ver joblog_robust.txt para detalles"

