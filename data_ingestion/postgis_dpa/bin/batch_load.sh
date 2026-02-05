#!/bin/bash
#####################################################################################
# MODIFICACIONES:														            #
# FECHA  		AUTOR     		DESCRIPCION MOTIVO						            #
# 2026-02-04	Diego Cuasapaz	Crear script de carga por lotes para optimización #
# 2026-02-04	Diego Cuasapaz	Automatizar detección de todos los Shapefiles #
#####################################################################################

PROCESO=BATCH_LOAD_DPA

# Ruta dinámica
VAL_RUTA=$(dirname $(readlink -f $0))
VAL_RUTA_LOG=/home/dcuasapaz/wrk/log
VAL_DIA=`date '+%Y%m%d'`
VAL_HORA=`date '+%H%M%S'`
VAL_LOG=$VAL_RUTA_LOG/$PROCESO"_"$VAL_DIA"_"$VAL_HORA.log

echo `date '+%Y-%m-%d %H:%M:%S'`" INFO: Iniciando carga automática de todos los Shapefiles" >>$VAL_LOG

# Cargar configuración
CONFIG_FILE="$VAL_RUTA/config.sh"
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
else
    echo "ERROR: Archivo de configuración $CONFIG_FILE no encontrado" >>$VAL_LOG
    exit 1
fi

# Crear tablas de logs si no existen
psql -U "$DB_USER" -d "$DB_NAME" -f "$(dirname $(dirname $(dirname $(readlink -f $0))))/sql/create_dpa_execution_logs.sql" >>$VAL_LOG 2>&1
psql -U "$DB_USER" -d "$DB_NAME" -f "$(dirname $(dirname $(dirname $(readlink -f $0))))/sql/create_dpa_metadata.sql" >>$VAL_LOG 2>&1

# Iniciar registro de ejecución del batch
BATCH_EXECUTION_ID=$$
BATCH_START_TIME=$(date +%Y-%m-%d\ %H:%M:%S)
$(dirname $(dirname $(dirname $(readlink -f $0))))/utils/log_execution.sh "$CONFIG_FILE" insert $BATCH_EXECUTION_ID "BATCH_LOAD_DPA" START "" "" "" "$BATCH_START_TIME" "" STARTED "Inicio carga automática de todos los Shapefiles"
get_srid() {
    local subdir=$1
    case $subdir in
        *INEC2012*|*DST_CRC*)
            echo "32717"  # UTM 17S para datos proyectados
            ;;
        *)
            echo "4326"   # WGS84 por defecto
            ;;
    esac
}

# Función para determinar nombre de tabla
get_table_name() {
    local filename=$1
    local subdir=$2
    # Convertir a minúsculas y agregar prefijo
    local base_name=$(echo "$filename" | tr '[:upper:]' '[:lower:]')
    echo "ec_ecu_${base_name}"
}

# Encontrar todos los archivos .shp en fnt/
FNT_DIR="$VAL_RUTA/../fnt"
find "$FNT_DIR" -name "*.shp" -type f | while read -r shp_file; do
    # Obtener información del archivo
    REL_PATH=${shp_file#"$FNT_DIR/"}
    FILE_NAME=$(basename "$shp_file" .shp)
    SUBDIR=$(dirname "$REL_PATH")
    
    # Determinar parámetros
    TABLE=$(get_table_name "$FILE_NAME" "$SUBDIR")
    SRID=$(get_srid "$SUBDIR")
    
    echo `date '+%Y-%m-%d %H:%M:%S'`" INFO: Detectado $shp_file -> Tabla: $TABLE, SRID: $SRID" >>$VAL_LOG
    
    # Ejecutar carga
    echo `date '+%Y-%m-%d %H:%M:%S'`" INFO: Cargando $TABLE desde $SUBDIR/$FILE_NAME.shp" >>$VAL_LOG
    bash $VAL_RUTA/load_shape.sh $TABLE $FILE_NAME $SRID $SUBDIR
    
    if [ $? -ne 0 ]; then
        echo `date '+%Y-%m-%d %H:%M:%S'`" ERROR: Fallo en carga de $TABLE" >>$VAL_LOG
        exit 1
    fi
    
    echo `date '+%Y-%m-%d %H:%M:%S'`" INFO: $TABLE cargado exitosamente" >>$VAL_LOG
done

# Finalizar registro de ejecución del batch
BATCH_END_TIME=$(date +%Y-%m-%d\ %H:%M:%S)
$(dirname $(dirname $(dirname $(readlink -f $0))))/utils/log_execution.sh "$CONFIG_FILE" insert $BATCH_EXECUTION_ID "BATCH_LOAD_DPA" FINISH "" "" "" "$BATCH_START_TIME" "$BATCH_END_TIME" SUCCESS "Carga automática completada"

echo `date '+%Y-%m-%d %H:%M:%S'`" INFO: Carga automática completada" >>$VAL_LOG