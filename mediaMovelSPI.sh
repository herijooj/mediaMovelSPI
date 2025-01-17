#!/bin/bash

# Implementado por Eduardo Machado (2015)
# Modified by Heric Camargo (2024)

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

set_colors() {
    RED='\033[1;31m'
    GREEN='\033[1;32m'
    YELLOW='\033[1;93m'
    BLUE='\033[1;36m'
    PURPLE='\033[1;35m'
    CYAN='\033[0;36m'
    GRAY='\033[0;90m'
    BOLD='\033[1m'
    NC='\033[0m'
}

if [ -t 1 ] && ! grep -q -e '--no-color' <<<"$@"
then
    set_colors
fi

extract_spi_months() {
    local filename=$1
    local spi_months=$(echo "$filename" | grep -o "spi[0-9]\+" | grep -o "[0-9]\+")
    if [ -z "$spi_months" ]; then
        echo "ERRO: Não foi possível extrair o número de meses SPI do nome do arquivo: $filename"
        exit 1
    fi
    echo "$spi_months"
}

ensure_output_dir() {
    local output_dir=$1
    if [ ! -d "$output_dir" ]; then
        mkdir -p "$output_dir"
        if [ $? -ne 0 ]; then
            echo "ERRO: Não foi possível criar o diretório de saída: $output_dir"
            exit 1
        fi
    fi
}

process_single_file() {
    local ARQ_CTL_IN=$1
    local OUTPUT_DIR=$2
    local N_MESES_SPI=$(extract_spi_months "$(basename "$ARQ_CTL_IN")")

    echo -e "\n${BOLD}${PURPLE}=== Processando arquivo: ${CYAN}$(basename "$ARQ_CTL_IN")${NC} ===\n"

    ARQ_BIN_IN="$(dirname $ARQ_CTL_IN)/$(grep dset $ARQ_CTL_IN | tr -s " " | cut -d" " -f2 | sed -e s/\\^//g)"
    ARQ_BIN_OUT="${OUTPUT_DIR}/$(basename $ARQ_BIN_IN .bin)_mmSPI${N_MESES_SPI}.bin"

    # Extrair parâmetros do arquivo de controle
    echo -e "${GRAY}[INFO]${NC} Extraindo parâmetros do arquivo de controle..."
    NX=$(cat ${ARQ_CTL_IN} | grep xdef | tr  "\t" " " | tr -s " " | cut -d" " -f2)
    NY=$(cat ${ARQ_CTL_IN} | grep ydef | tr  "\t" " " | tr -s " " | cut -d" " -f2)
    NZ=$(cat ${ARQ_CTL_IN} | grep zdef | tr  "\t" " " | tr -s " " | cut -d" " -f2)
    NT=$(cat ${ARQ_CTL_IN} | grep tdef | tr  "\t" " " | tr -s " " | cut -d" " -f2)
    UNDEF=$(cat ${ARQ_CTL_IN} | grep undef | tr  "\t" " " | tr -s " " | cut -d" " -f2)
    VAR=$(grep -A1 -i -w '^vars' ${ARQ_CTL_IN} | tail -n1 | awk '{print $1}')

    echo -e "${BLUE}[CONFIG]${NC} Processando com ${YELLOW}$N_MESES_SPI${NC} meses de SPI"
    echo -e "${GRAY}[INFO]${NC} Executando média móvel..."

    if $SCRIPT_DIR/bin/media_movel ${ARQ_BIN_IN} ${NX} ${NY} ${NZ} ${NT} ${UNDEF} ${N_MESES_SPI} ${ARQ_BIN_OUT}; then
        echo -e "${GREEN}[SUCESSO]${NC} Média móvel calculada com sucesso"
    else
        echo -e "${RED}[FALHA]${NC} Erro no cálculo da média móvel"
        exit 1
    fi

    # Criar arquivo de controle de saída
    ARQ_CTL_OUT="${OUTPUT_DIR}/$(basename $ARQ_CTL_IN .ctl)_mmSPI${N_MESES_SPI}.ctl"
    echo -e "${GRAY}[INFO]${NC} Gerando arquivo de controle..."
    cp $ARQ_CTL_IN $ARQ_CTL_OUT
    sed -i "s#$(basename $ARQ_BIN_IN .bin)#$(basename $ARQ_BIN_OUT .bin)#g" ${ARQ_CTL_OUT}

    echo -e "${GRAY}─────────────────────────────────────────${NC}"
}

print_usage() {
    echo ""
    echo "Uso: mediaMovelSPI [ARQ_CTL_ENTRADA ou DIRETORIO] [-o DIRETORIO_SAIDA]"
    echo "     Se -o não for especificado, será usado o diretório '[arqin]_mmSPI'"
    echo ""
}

OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            INPUT="$1"
            shift
            ;;
    esac
done

if [ -z "$INPUT" ]; then
    echo "ERRO! Arquivo de entrada não especificado!"
    print_usage
    exit 1
fi

if [ -z "$OUTPUT_DIR" ]; then
    #output_dir vai ser uma nova pasta com o nome do arquivo de entrada + _mmSPI
    OUTPUT_DIR="$(dirname "$INPUT")/$(basename "$INPUT" .ctl)_mmSPI"
fi

ensure_output_dir "$OUTPUT_DIR"

if [ -d "$INPUT" ]; then
    echo "Processando diretório: $INPUT"
    for arquivo in "$INPUT"/*.ctl; do
        if [ -f "$arquivo" ]; then
            process_single_file "$arquivo" "$OUTPUT_DIR"
        fi
    done
elif [ -f "$INPUT" ]; then
    process_single_file "$INPUT" "$OUTPUT_DIR"
else
    echo "ERRO: '$INPUT' não é um arquivo ou diretório válido"
    exit 1
fi
