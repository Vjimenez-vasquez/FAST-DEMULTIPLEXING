#!/bin/bash

# Configuración optimizada para 24 núcleos
JOBS=23  # 20 jobs para dejar 4 núcleos libres para el sistema
COMBINATIONS_FILE="combinations.txt"

echo "=== FASTQ-MULTX PARALELO OPTIMIZADO ==="
echo "Jobs en paralelo: $JOBS"
echo "Núcleos disponibles: 24"
echo "RAM disponible: 220GB"
echo "Combinaciones a procesar: $(wc -l < $COMBINATIONS_FILE)"
echo "Inicio: $(date)"
echo "========================================"

# Función para procesar UNA combinación
process_combination() {
    local line="$1"
    
    # Separar los campos usando @ como delimitador
    IFS='@' read -r F R P <<< "$line"
    
    # Limpiar espacios en blanco
    F=$(echo "$F" | xargs)
    R=$(echo "$R" | xargs)
    P=$(echo "$P" | xargs)
    
    B="${P}_barcodes.txt"
    OUTPUT_DIR="${P}_02"
    
    echo "[$(date '+%H:%M:%S')] INICIANDO: $P"
    echo "  Forward: $F"
    echo "  Reverse: $R"
    echo "  Barcodes: $B"
    
    # Verificaciones de archivos
    if [[ ! -f "$F" ]]; then
        echo "  ❌ ERROR: No existe archivo forward: $F"
        return 1
    fi
    
    if [[ ! -f "$R" ]]; then
        echo "  ❌ ERROR: No existe archivo reverse: $R"
        return 1
    fi
    
    if [[ ! -f "$B" ]]; then
        echo "  ❌ ERROR: No existe archivo de barcodes: $B"
        return 1
    fi
    
    # Crear directorio de salida
    mkdir -p "$OUTPUT_DIR"
    
    # Ejecutar fastq-multx
    echo "  🚀 Ejecutando fastq-multx..."
    fastq-multx -b -B "$B" "$F" "$R" -o "${OUTPUT_DIR}/%.R1.fastq.gz" "${OUTPUT_DIR}/%.R2.fastq.gz" -m 1 -d 1  
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        echo "  ✅ COMPLETADO: $P"
    else
        echo "  ❌ ERROR (código $exit_code) en: $P"
    fi
    
    return $exit_code
}

# Exportar la función para que parallel pueda usarla
export -f process_combination

# Ejecutar en paralelo
echo "Iniciando procesamiento paralelo..."
parallel -j $JOBS \
    --progress \
    --joblog "multx_joblog_$(date +%Y%m%d_%H%M%S).txt" \
    --eta \
    --resume-failed \
    process_combination :::: "$COMBINATIONS_FILE"

echo "========================================"
echo "Procesamiento completado: $(date)"
echo "Revisar log: multx_joblog_*.txt"
echo "========================================"

